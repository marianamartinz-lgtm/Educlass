import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'database/db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  BancoDados.inicializarSQLite();
  await BancoDados.database;

  await AppData.init();

  runApp(const EduClassApp());
}

const Color primary = Color(0xFF0F766E);
const Color primaryDark = Color(0xFF0B4F4A);
const Color accent = Color(0xFFFF7A59);
const Color secondary = Color(0xFF2563EB);
const Color pageBg = Color(0xFFF4F8F7);

class AppData {
  static late SharedPreferences prefs;
  static String name = 'Ana Paula Silva';
  static String email = 'ana@educlass.com';
  static String password = '';
  static String subject = 'Matemática';
  static String school = 'Escola Estadual Horizonte';
  static XFile? profilePhoto;
  static String? profilePhotoBase64;
  static bool newAccount = false;
  static bool accountCreated = false;
  static String stateName = '';
  static String cityName = '';
  static String cityCode = '';
  static String googleEmail = '';
  static String googleName = '';
  static List<String> selectedSubjects = ['Matemática'];
  static List pendingTasks = [
    'Lançar notas do 3º A',
    'Registrar chamada de terça-feira',
    'Preparar atividade de revisão',
  ];
  static List<Map<String, dynamic>> actionPlans = [
    {'title': 'Acompanhamento 3º A', 'deadline': '18/09/2026', 'status': 'Em andamento'},
    {'title': 'Reunião pedagógica', 'deadline': '22/09/2026', 'status': 'Pendente'},
  ];
  static List<Map<String, dynamic>> communications = [];
  static List<Map<String, dynamic>> meetings = [];
  static List<Map<String, dynamic>> lessonPlans = [];

  static Future init() async {
    prefs = await SharedPreferences.getInstance();
    accountCreated = prefs.getBool('accountCreated') ?? false;
    name = prefs.getString('name') ?? name;
    email = prefs.getString('email') ?? email;
    password = prefs.getString('password') ?? '';
    subject = prefs.getString('subject') ?? subject;
    school = prefs.getString('school') ?? school;
    stateName = prefs.getString('stateName') ?? '';
    cityName = prefs.getString('cityName') ?? '';
    cityCode = prefs.getString('cityCode') ?? '';
    googleEmail = prefs.getString('googleEmail') ?? '';
    googleName = prefs.getString('googleName') ?? '';
    final rawSubjects = prefs.getString('selectedSubjects');
    if (rawSubjects != null) selectedSubjects = List<String>.from(jsonDecode(rawSubjects));
    final rawTasks = prefs.getString('pendingTasks');
    if (rawTasks != null) pendingTasks = List.from(jsonDecode(rawTasks));
    final rawPlans = prefs.getString('actionPlans');
    if (rawPlans != null) actionPlans = (jsonDecode(rawPlans) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final rawComms = prefs.getString('communications');
    if (rawComms != null) communications = (jsonDecode(rawComms) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final rawMeetings = prefs.getString('meetings');
    if (rawMeetings != null) meetings = (jsonDecode(rawMeetings) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final rawLessonPlans = prefs.getString('lessonPlans');
    if (rawLessonPlans != null) lessonPlans = (jsonDecode(rawLessonPlans) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    profilePhotoBase64 = prefs.getString('profilePhotoBase64');

    final rawSchools = prefs.getString('schools');
    if (rawSchools != null) {
      schools = List<String>.from(jsonDecode(rawSchools));
    }

    final rawClasses = prefs.getString('classes');
    if (rawClasses != null) {
      classes = (jsonDecode(rawClasses) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    final rawEvents = prefs.getString('events');
    if (rawEvents != null) {
      events = (jsonDecode(rawEvents) as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['date'] = DateTime.tryParse(m['date'].toString()) ?? DateTime.now();
        return m;
      }).toList();
    }

    final rawRecords = prefs.getString('studentRecords');
    if (rawRecords != null) {
      final raw = jsonDecode(rawRecords) as Map;
      studentRecords.clear();
      raw.forEach((key, value) {
        final item = Map<String, dynamic>.from(value as Map);
        item['grades'] = (item['grades'] as List? ?? [])
            .map((e) => (e as num).toDouble())
            .toList();
        item['absences'] = (item['absences'] as num? ?? 0).toInt();
        item['occurrences'] = (item['occurrences'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        item['notes'] = item['notes']?.toString() ?? '';
        item['studentPhoto'] = item['studentPhoto']?.toString();
        item['attendance'] = Map<String, dynamic>.from(
          (item['attendance'] as Map?) ?? <dynamic, dynamic>{},
        );
        studentRecords[key.toString()] = item;
      });
    }

    if (accountCreated && schools.isEmpty) {
      schools = [school];
    }
  }

  static Future save() async {
    await prefs.setBool('accountCreated', accountCreated);
    await prefs.setString('name', name);
    await prefs.setString('email', email);
    await prefs.setString('password', password);
    await prefs.setString('subject', subject);
    await prefs.setString('school', school);
    await prefs.setString('stateName', stateName);
    await prefs.setString('cityName', cityName);
    await prefs.setString('cityCode', cityCode);
    await prefs.setString('googleEmail', googleEmail);
    await prefs.setString('googleName', googleName);
    await prefs.setString('selectedSubjects', jsonEncode(selectedSubjects));
    await prefs.setString('pendingTasks', jsonEncode(pendingTasks));
    await prefs.setString('actionPlans', jsonEncode(actionPlans));
    await prefs.setString('communications', jsonEncode(communications));
    await prefs.setString('meetings', jsonEncode(meetings));
    await prefs.setString('lessonPlans', jsonEncode(lessonPlans));

    if (profilePhotoBase64 == null || profilePhotoBase64!.isEmpty) {
      await prefs.remove('profilePhotoBase64');
    } else {
      await prefs.setString('profilePhotoBase64', profilePhotoBase64!);
    }

    await prefs.setString('schools', jsonEncode(schools));
    await prefs.setString('classes', jsonEncode(classes));

    final jsonEvents = events.map((e) {
      final m = Map.from(e);
      if (m['date'] is DateTime) {
        m['date'] = (m['date'] as DateTime).toIso8601String();
      }
      return m;
    }).toList();

    await prefs.setString('events', jsonEncode(jsonEvents));
    await prefs.setString('studentRecords', jsonEncode(studentRecords));
  }

  static final List<String> classOptions = [
    for (int i = 1; i <= 9; i++) ...[
      '$iº Ano Fundamental A',
      '$iº Ano Fundamental B',
    ],
    '1º Ano Ensino Médio A',
    '1º Ano Ensino Médio B',
    '2º Ano Ensino Médio A',
    '2º Ano Ensino Médio B',
    '3º Ano Ensino Médio A',
    '3º Ano Ensino Médio B',
  ];

  static final Map<String, List<String>> studentsByClass = {
    '3º Ano Ensino Médio A': [
      'ANA BEATRIZ PEREIRA DOS SANTOS',
      'ANA CLARA DE CARVALHO NASCIMENTO',
      'ANNA LUIZA GOMES SILVA',
      'AQUILES LUIZ NUNES BASTOS',
      'CAINAN BASTOS DA SILVA',
      'DERICK LUIZ CAETANO MIGUEL',
      'ESTELLA DE ALMEIDA ROSA',
      'FRANCISCO GABRIEL DE OLIVEIRA PASSOS',
      'GLORIA MARIA MOURA BRUNO DE CARVALHO',
      'HELOISA FRANCISCO DIONISIO',
      'HENRY GUIMARÃES ALVES',
      'INGRID RANI FORTUNATO DOS SANTOS',
      'JOÃO GABRIEL DA SILVA PEREIRA',
      'JOÃO PEDRO DE AQUINO HONORATO',
      'JOÃO PEDRO MARTINS LIGABO',
      'JOÃO PEDRO RODRIGUES DOS SANTOS',
      'JUAN PEDRO DE MIRANDA',
      'JULIA DE MOURA LOPES DA SILVA',
      'MARCOS VINICIUS SORIANO GUATURA',
      'MARIA EDUARDA FELIX INOCENCIO',
      'MARIA ISABEL DA SILVA COSTA BORGES',
      'MARIANA DE SOUZA MARTINS DOS SANTOS',
      'MARIANA SILVA DE ANDRADE',
      'MIGUEL ARAUJO DE GODOI FREITAS',
      'NATHALIA ALVES ABDO REZENDE',
      'NEIL LOPES JOÃO FILHO',
      'NICOLAS FELIPE DO NASCIMENTO ROSA',
      'PIETRO HENRIQUE GOMES DE ANDRADE',
      'SAMUEL RODRIGUES COSTA FREIRE',
      'VICTOR HUGO DO CARMO DE JESUS',
    ],
    '3º Ano Ensino Médio B': [
      'Ágatha Gerônimo de Souza',
      'Agatha Mytria Eugênio Galvão',
      'Alicia Souza Reis Fabiano',
      'Ana Clara da Silva Lopes',
      'Ana Clara da Silva Rosa',
      'Ana Clara Rodrigues',
      'Anna Beatriz Gonzaga Fialho',
      'Anna Carolina de Almeida',
      'Anna Livia Rachel dos Santos',
      'Bárbara Guatura Chagas',
      'Gabriel Ivanildo Araujo de Carvalho',
      'Gabriel Luiz Andrade de Oliveira',
      'Gabriela dos Santos Cardoso Alves',
      'José Luiz de Sousa Oliveira',
      'Julia Helena Diniz da Silva',
      'Jullia Bastos Ribeiro',
      'Kalel da Cunha Souza Fernandes',
      'Kauan da Silva Santos',
      'Luiz Guilherme de Alcantara Silva',
      'Maria Clara Dias Baesso',
      'Marianny Orfão Terra',
      'Melissa Espindola',
      'Miguel de Oliveira Rodrigues da Silva',
      'Murilo Gonçalves Parreiras Jannuzzelli',
      'Natalia Aquino de Almeida',
      'Nathan da Silva Santos',
      'Nicoly Souza Marioto',
      'Paola Diniz de Souza',
      'Rafael Massao de Oliveira',
      'Renata Ageu da Silva Cardoso',
      'Yago Andrade Molina',
      'Miguel da Silva Miranda Rodrigues',
    ],
  };

  static List<Map<String, dynamic>> classes = [
    {
      'name': '3º Ano Ensino Médio A',
      'day': 'Segunda-feira',
      'time': '08:00 - 09:40',
      'room': 'Sala 12',
      'color': 0xFF5630C9,
    },
    {
      'name': '3º Ano Ensino Médio B',
      'day': 'Quarta-feira',
      'time': '10:00 - 11:40',
      'room': 'Sala 14',
      'color': 0xFF2979FF,
    },
  ];

  static List<Map<String, dynamic>> events = [
    {
      'date': DateTime(2026, 9, 7),
      'title': 'Independência do Brasil',
      'type': 'Feriado',
      'time': 'Dia todo',
      'school': 'Todas',
      'description': 'Feriado nacional.',
    },
    {
      'date': DateTime(2026, 9, 15),
      'title': 'Reunião Pedagógica',
      'type': 'Reunião',
      'time': '14:00 - 15:30',
      'school': 'Escola Estadual Horizonte',
      'description': 'Reunião de planejamento pedagógico.',
    },
    {
      'date': DateTime(2026, 9, 24),
      'title': 'Conselho de Classe',
      'type': 'Conselho',
      'time': '17:00 - 18:30',
      'school': 'Escola Estadual Horizonte',
      'description': 'Conselho do 3º ano.',
    },
  ];

  static final List<Map<String, String>> holidays = [
    {'date': '01/01/2026', 'title': 'Confraternização Universal'},
    {'date': '03/04/2026', 'title': 'Paixão de Cristo'},
    {'date': '21/04/2026', 'title': 'Tiradentes'},
    {'date': '01/05/2026', 'title': 'Dia Mundial do Trabalho'},
    {'date': '04/06/2026', 'title': 'Corpus Christi'},
    {'date': '07/09/2026', 'title': 'Independência do Brasil'},
    {'date': '12/10/2026', 'title': 'Nossa Senhora Aparecida'},
    {'date': '02/11/2026', 'title': 'Finados'},
    {'date': '15/11/2026', 'title': 'Proclamação da República'},
    {'date': '20/11/2026', 'title': 'Dia da Consciência Negra'},
    {'date': '25/12/2026', 'title': 'Natal'},
  ];

  static List<String> schools = ['Escola Estadual Horizonte'];

  static final Map<String, Map<String, dynamic>> studentRecords = {};

  static Future clearForNewAccount() async {
    classes = [];
    events = [];
    schools = [school.isEmpty ? 'Minha escola' : school];
    selectedSubjects = subject.isEmpty ? ['Matemática'] : [subject];
    pendingTasks = ['Cadastrar primeira turma', 'Planejar a primeira aula'];
    actionPlans = [];
    communications = [];
    meetings = [];
    lessonPlans = [];
    studentRecords.clear();
    newAccount = true;
    await save();
  }

  static List<String> studentsFor(String className) {
    return studentsByClass[className] ?? [];
  }

  static Map<String, dynamic> recordFor(String className, String student) {
    final key = '$className|$student';
    return studentRecords.putIfAbsent(
      key,
      () => {
        'grades': [],
        'absences': 0,
        'occurrences': [],
        'notes': '',
        'studentPhoto': null,
        'attendance': {},
      },
    );
  }
}

class EduClassApp extends StatefulWidget {
  const EduClassApp({super.key});

  @override
  State<EduClassApp> createState() => _EduClassAppState();
}

class _EduClassAppState extends State<EduClassApp> {
  bool dark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EduClass',
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: SplashPage(
        onThemeChanged: (value) => setState(() => dark = value),
      ),
    );
  }
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, secondary: accent, brightness: brightness),
    scaffoldBackgroundColor: dark ? const Color(0xFF12101A) : pageBg,
    fontFamily: 'Arial',
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF12101A) : pageBg,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF211D2B) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: primary.withOpacity(.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: primary.withOpacity(.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),
  );
}


class SplashPage extends StatefulWidget {
  final ValueChanged<bool> onThemeChanged;
  const SplashPage({super.key, required this.onThemeChanged});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginPage(onThemeChanged: widget.onThemeChanged)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF063F47), Color(0xFF0F766E), Color(0xFF145DA0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -80, left: -60, child: _DecorCircle(size: 240)),
            Positioned(bottom: -100, right: -70, child: _DecorCircle(size: 280)),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.96),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Logo(size: 150),
                  ),
                  const SizedBox(height: 24),
                  const Text('EduClass', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 7),
                  const Text('Educação organizada. Rotina mais leve.', style: TextStyle(color: Colors.white70, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 50});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/educlass_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .22),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
            ),
          ),
          child: Icon(Icons.school_rounded, color: Colors.white, size: size * .58),
        ),
      ),
    );
  }
}


class LoginPage extends StatefulWidget {
  final ValueChanged<bool> onThemeChanged;
  const LoginPage({super.key, required this.onThemeChanged});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool googleLoading = false;

  Future<void> loginComGoogle() async {
    if (googleLoading) return;

    setState(() => googleLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        throw Exception('Login com Google cancelado.');
      }

      AppData.googleName = account.displayName ?? '';
      AppData.googleEmail = account.email;
      AppData.name = AppData.googleName.isEmpty
          ? account.email.split('@').first
          : AppData.googleName;
      AppData.email = account.email;
      AppData.accountCreated = true;
      await AppData.save();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(onThemeChanged: widget.onThemeChanged),
        ),
      );
    } catch (e) {
      if (mounted) {
        snack(context, 'Não foi possível entrar com o Google. Verifique a configuração do Google Sign-In.');
      }
    } finally {
      if (mounted) setState(() => googleLoading = false);
    }
  }

  Future<void> enter() async {
    final emailDigitado = email.text.trim().toLowerCase();
    final senhaDigitada = password.text;

    if (emailDigitado.isEmpty || senhaDigitada.isEmpty) {
      snack(context, 'Preencha e-mail e senha.');
      return;
    }

    try {
      // O login agora consulta o SQLite.
      // Isso permite entrar com qualquer usuário que tenha sido salvo no banco.
      final usuario = await BancoDados.buscarUsuario(emailDigitado);

      if (usuario == null) {
        if (mounted) snack(context, 'Usuário não encontrado no SQLite.');
        return;
      }

      if (usuario['senha'].toString() != senhaDigitada) {
        if (mounted) snack(context, 'E-mail ou senha incorretos.');
        return;
      }

      // Recarrega os dados do usuário para a sessão do aplicativo.
      AppData.name = usuario['nome']?.toString() ?? '';
      AppData.email = usuario['email']?.toString() ?? emailDigitado;
      AppData.password = usuario['senha']?.toString() ?? senhaDigitada;
      AppData.school = usuario['escola']?.toString() ?? '';
      AppData.cityName = usuario['municipio']?.toString() ?? '';
      AppData.stateName = usuario['estado']?.toString() ?? '';
      AppData.accountCreated = true;
      await AppData.save();

      if (!mounted) return;

      snack(context, 'Login realizado com sucesso!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(onThemeChanged: widget.onThemeChanged),
        ),
      );
    } catch (e) {
      if (mounted) {
        snack(context, 'Erro ao acessar o SQLite: $e');
      }
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF063F47), Color(0xFF0F766E), Color(0xFF145DA0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -90, right: -70, child: _DecorCircle(size: 260)),
            Positioned(bottom: -110, left: -90, child: _DecorCircle(size: 300)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1020),
                    child: Card(
                      elevation: 0,
                      color: Colors.white.withOpacity(.96),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final two = constraints.maxWidth >= 760;
                            final form = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Logo(size: 90),
                                const SizedBox(height: 12),
                                const Text('Bem-vindo ao EduClass', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 5),
                                const Text('Seu espaço para organizar aulas, turmas, recados e recursos pedagógicos.', style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 25),
                                TextField(
                                  controller: email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline)),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: password,
                                  obscureText: obscure,
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => obscure = !obscure),
                                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  height: 54,
                                  child: FilledButton(onPressed: enter, child: const Text('Entrar', style: TextStyle(fontWeight: FontWeight.w800))),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 54,
                                  child: OutlinedButton.icon(
                                    onPressed: googleLoading ? null : loginComGoogle,
                                    icon: googleLoading
                                        ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                                    label: Text(googleLoading ? 'Conectando...' : 'Continuar com o Google'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterPage(onThemeChanged: widget.onThemeChanged))),
                                  child: const Text('Criar uma nova conta'),
                                ),
                              ],
                            );

                            if (!two) return form;
                            return Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 28),
                                    child: _LoginWelcome(),
                                  ),
                                ),
                                Container(width: 1, height: 430, color: Colors.black12),
                                const SizedBox(width: 28),
                                Expanded(flex: 4, child: form),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  const _DecorCircle({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(.05),
          border: Border.all(color: Colors.white.withOpacity(.08), width: 2),
        ),
      );
}

class _LoginWelcome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Logo(size: 150),
        const SizedBox(height: 18),
        const Text('EduClass', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: primaryDark)),
        const SizedBox(height: 10),
        const Text(
          'Tudo que um professor precisa para transformar a rotina escolar em um fluxo organizado.',
          style: TextStyle(fontSize: 19, height: 1.45, color: Colors.black87),
        ),
        const SizedBox(height: 22),
        ...[
          ['Turmas e alunos', Icons.groups_outlined],
          ['Recados e mensagens prontas', Icons.forum_outlined],
          ['Videoaulas e artigos científicos', Icons.auto_stories_outlined],
        ].map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: primary),
              const SizedBox(width: 9),
              Text(e[0] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        )),
      ],
    );
  }
}

class RegisterPage extends StatefulWidget {
  final ValueChanged<bool> onThemeChanged;
  const RegisterPage({super.key, required this.onThemeChanged});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  String? stateId;
  String? stateName;
  String? cityId;
  String? cityName;
  String? schoolName;
  List<Map<String, String>> states = [];
  List<Map<String, String>> cities = [];
  List<String> schools = [];
  bool loadingStates = true, loadingCities = false, loadingSchools = false;
  bool saving = false;
  final subjects = const [
    'Matemática','Português','História','Geografia','Biologia','Química','Física',
    'Inglês','Artes','Educação Física','Filosofia','Sociologia','Robótica',
    'Programação','Projeto de Vida','Ciências','Ensino Religioso'
  ];
  final selected = {'Matemática'};

  @override
  void initState() {
    super.initState();
    loadStates();
  }

  Future<List<dynamic>> getJson(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('Falha ${response.statusCode}');
    return jsonDecode(response.body) as List;
  }

  Future loadStates() async {
    try {
      final data = await getJson('https://servicodados.ibge.gov.br/api/v1/localidades/estados');
      states = data.map<Map<String, String>>((e) => {'id': e['id'].toString(), 'sigla': e['sigla'].toString(), 'nome': e['nome'].toString()}).toList();
      states.sort((a,b) => (a['nome'] as String).compareTo(b['nome'] as String));
    } catch (_) {}
    if (mounted) setState(() => loadingStates = false);
  }

  Future loadCities(String id) async {
    setState(() { loadingCities = true; cities = []; cityId = null; cityName = null; schoolName = null; schools = []; });
    try {
      final data = await getJson('https://servicodados.ibge.gov.br/api/v1/localidades/estados/$id/municipios');
      cities = data.map<Map<String, String>>((e) => {'id': e['id'].toString(), 'nome': e['nome'].toString()}).toList();
      cities.sort((a,b) => (a['nome'] as String).compareTo(b['nome'] as String));
    } catch (_) {}
    if (mounted) setState(() => loadingCities = false);
  }

  Future<void> loadSchools(String ibgeCode) async {
    if (!mounted) return;

    setState(() {
      loadingSchools = true;
      schools = [];
      schoolName = null;
    });

    final schoolNames = <String>{};

    String? uf;
    try {
      final state = states.firstWhere(
        (e) => e['id'] == stateId,
        orElse: () => <String, String>{},
      );
      uf = state['sigla'];
    } catch (_) {}

    // Fonte pública da Nossa Escola/TCU. O endpoint permite filtrar por
    // município e UF e paginar os resultados.
    if (cityName != null && uf != null && uf!.isNotEmpty) {
      try {
        for (var page = 0; page < 10; page++) {
          final uri = Uri.https(
            'mobile-aceite.tcu.gov.br',
            '/nossaEscolaRS/rest/escolas/',
            {
              'municipio': cityName!,
              'uf': uf,
              'situacaoFuncionamento': 'Em Atividade',
              'pagina': '$page',
              'quantidadeDeItens': '500',
            },
          );

          final response = await http.get(
            uri,
            headers: const {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode != 200 || response.body.trim().isEmpty) break;

          final decoded = jsonDecode(response.body);
          final list = decoded is List
              ? decoded
              : decoded is Map
                  ? (decoded['content'] ?? decoded['results'] ?? decoded['data'] ?? decoded['escolas'] ?? [])
                  : [];

          if (list is! List || list.isEmpty) break;

          var addedThisPage = 0;
          for (final item in list) {
            if (item is! Map) continue;
            final name = (item['nome'] ?? item['nome_escola'] ?? item['no_entidade'] ?? item['escola'] ?? '')
                .toString()
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            if (name.isNotEmpty && schoolNames.add(name)) addedThisPage++;
          }

          if (addedThisPage == 0 || list.length < 500) break;
        }
      } catch (_) {
        // Tenta a segunda fonte abaixo.
      }
    }

    // Segunda fonte: API pública de dados abertos do INEP.
    if (schoolNames.isEmpty) {
      final urls = <Uri>[
        Uri.parse('http://api.dadosabertosinep.org/v1/ideb/escolas.json?codigo_municipio=$ibgeCode'),
        Uri.parse('http://api.dadosabertosinep.org/v1/ideb/escolas.json?codigo_municipio=$ibgeCode&rede=publica'),
      ];

      for (final uri in urls) {
        try {
          final response = await http.get(
            uri,
            headers: const {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 15));
          if (response.statusCode != 200 || response.body.trim().isEmpty) continue;

          final decoded = jsonDecode(response.body);
          final list = decoded is List
              ? decoded
              : decoded is Map
                  ? (decoded['results'] ?? decoded['data'] ?? decoded['escolas'] ?? decoded['content'] ?? [])
                  : [];

          if (list is List) {
            for (final item in list) {
              if (item is! Map) continue;
              final name = (item['nome_escola'] ?? item['nome'] ?? item['no_entidade'] ?? item['escola'] ?? item['nomeInstituicao'] ?? item['NO_ENTIDADE'] ?? '')
                  .toString()
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();
              if (name.isNotEmpty) schoolNames.add(name);
            }
          }
          if (schoolNames.isNotEmpty) break;
        } catch (_) {}
      }
    }

    final normalized = schoolNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (!mounted) return;
    setState(() {
      schools = normalized;
      loadingSchools = false;
    });

    if (schools.isEmpty && mounted) {
      await _manualSchoolFallback();
    }
  }

  Future<void> _manualSchoolFallback() async {
    if (!mounted || cityId == null) return;

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Escola não encontrada automaticamente'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome da escola',
            hintText: 'Digite o nome completo ou uma parte',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Usar esta escola'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (!mounted || result == null || result.isEmpty) return;

    setState(() {
      if (!schools.contains(result)) schools.add(result);
      schools.sort();
      schoolName = result;
    });
  }

  Future<void> create() async {
    if (name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.length < 6 ||
        stateId == null ||
        cityId == null ||
        schoolName == null ||
        selected.isEmpty) {
      snack(
        context,
        'Preencha todos os dados do cadastro. A senha precisa ter 6 caracteres.',
      );
      return;
    }

    if (saving) return;

    setState(() => saving = true);

    try {
      // Salva o cadastro diretamente no SQLite local do aplicativo.
      // Todos os campos do cadastro são enviados para o banco.
      await BancoDados.inserirUsuario(
        nome: name.text.trim(),
        email: email.text.trim(),
        senha: password.text,
        escola: schoolName!,
        municipio: cityName ?? '',
        estado: stateName ?? '',
        materias: selected.toList(),
      );

      // Também salva os dados localmente para manter a sessão
      // e as configurações do aplicativo.
      AppData.name = name.text.trim();
      AppData.email = email.text.trim();
      AppData.password = password.text;
      AppData.subject = selected.first;
      AppData.selectedSubjects = selected.toList();
      AppData.school = schoolName!;
      AppData.stateName = stateName ?? '';
      AppData.cityName = cityName ?? '';
      AppData.cityCode = cityId!;
      AppData.accountCreated = true;

      await AppData.clearForNewAccount();

      if (!mounted) return;

      snack(context, 'Cadastro salvo no banco com sucesso!');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            onThemeChanged: widget.onThemeChanged,
          ),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      final erro = e.toString().toLowerCase();
      String mensagem = 'Não foi possível salvar o cadastro.';

      if (erro.contains('duplicate') ||
          erro.contains('unique') ||
          erro.contains('já existe')) {
        mensagem = 'Este e-mail já está cadastrado.';
      } else if (erro.contains('socket') ||
          erro.contains('connection') ||
          erro.contains('localhost') ||
          erro.contains('connection refused')) {
        mensagem =
            'Não foi possível conectar ao servidor. Verifique se o backend está rodando.';
      }

      debugPrint('ERRO AO CADASTRAR PROFESSOR: $e');
      snack(context, mensagem);
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget fieldLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')), 
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Logo(size: 64), const SizedBox(height: 12),
        const Text('Seu espaço começa aqui', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text('Configure seu perfil uma vez e deixe o EduClass organizar sua rotina.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 22),
        fieldLabel('Nome completo'), TextField(controller: name, decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), hintText: 'Ex.: Ana Paula Silva')),
        const SizedBox(height: 13), fieldLabel('E-mail'), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline), hintText: 'seu@email.com')),
        const SizedBox(height: 13), fieldLabel('Senha'), TextField(controller: password, obscureText: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline), hintText: 'Mínimo de 6 caracteres')),
        const SizedBox(height: 18),
        fieldLabel('Estado'),
        DropdownButtonFormField<String>(value: stateId, isExpanded: true, hint: Text(loadingStates ? 'Carregando estados...' : 'Selecione o estado'), items: states.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text('${e['sigla']} — ${e['nome']}'))).toList(), onChanged: (String? v) async { if (v == null) return; final item = states.firstWhere((e) => e['id'] == v); setState(() { stateId = v; stateName = item['nome'] ?? ''; cityId = null; cityName = null; schoolName = null; cities = []; schools = []; }); await loadCities(v); }),
        const SizedBox(height: 13), fieldLabel('Município'),
        DropdownButtonFormField<String>(value: cityId, isExpanded: true, hint: Text(loadingCities ? 'Carregando municípios...' : stateId == null ? 'Escolha primeiro o estado' : 'Selecione o município'), items: cities.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['nome'] ?? ''))).toList(), onChanged: (String? v) async { if (v == null) return; final item = cities.firstWhere((e) => e['id'] == v); setState(() { cityId = v; cityName = item['nome'] ?? ''; schoolName = null; schools = []; }); await loadSchools(v); setState(() {}); }),
        const SizedBox(height: 13), fieldLabel('Escola'),
        DropdownButtonFormField<String>(value: schoolName, isExpanded: true, hint: Text(loadingSchools ? 'Buscando escolas...' : cityId == null ? 'Escolha o município primeiro' : schools.isEmpty ? 'Nenhuma escola encontrada — toque para informar' : 'Selecione sua escola'), items: schools.map((e) => DropdownMenuItem<String>(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(), onChanged: (String? v) => setState(() => schoolName = v)),
        if (cityId != null) Padding(padding: const EdgeInsets.only(top: 7), child: Text('${schools.length} escola(s) encontrada(s) para o município selecionado.', style: const TextStyle(color: Colors.grey, fontSize: 12))),
        const SizedBox(height: 18), fieldLabel('Matérias que você leciona'),
        Wrap(spacing: 7, runSpacing: 7, children: subjects.map((s) => FilterChip(label: Text(s), selected: selected.contains(s), onSelected: (v) => setState(() { v ? selected.add(s) : selected.remove(s); }))).toList()),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: saving ? null : create,
          icon: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.rocket_launch_outlined),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              saving ? 'Salvando no banco...' : 'Criar conta e entrar',
            ),
          ),
        ),
        const SizedBox(height: 10), const Text('Os municípios são carregados da API do IBGE. A listagem de escolas usa uma base aberta do INEP quando disponível.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11)),
      ]),
    );
  }
}


class HomePage extends StatefulWidget {
  final ValueChanged<bool> onThemeChanged;
  const HomePage({super.key, required this.onThemeChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  void refresh() => setState(() {});

  List<Widget> get pages => [
        DashboardPage(onRefresh: refresh),
        ClassesPage(onChanged: refresh),
        CalendarPage(onChanged: refresh),
        const CommunicationPage(),
        const LessonPlannerPage(),
        const ReportsPage(),
        const ActivityIdeasPage(),
        const VideoLessonsPage(),
        const ScientificArticlesPage(),
        const WellBeingPage(),
        const ActionPlanPage(),
        MorePage(onThemeChanged: widget.onThemeChanged, onChanged: refresh),
      ];

  static const labels = [
    'Início',
    'Turmas',
    'Calendário',
    'Comunicação',
    'Planejar aula',
    'Relatórios',
    'Banco de ideias',
    'Videoaulas',
    'Artigos científicos',
    'Bem-estar',
    'Pendências',
    'Mais',
  ];

  static const icons = [
    Icons.home_outlined,
    Icons.groups_outlined,
    Icons.calendar_month_outlined,
    Icons.forum_outlined,
    Icons.edit_calendar_outlined,
    Icons.bar_chart_outlined,
    Icons.lightbulb_outline,
    Icons.ondemand_video_outlined,
    Icons.science_outlined,
    Icons.favorite_outline,
    Icons.checklist_rounded,
    Icons.apps_outlined,
  ];

  void openIndex(int value) => setState(() => index = value);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 242,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF083F45), Color(0xFF0F766E), Color(0xFF145DA0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Row(
                        children: [
                          const Logo(size: 48),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'EduClass',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: labels.length,
                        itemBuilder: (_, i) {
                          final selected = index == i;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            child: Material(
                              color: selected ? Colors.white.withOpacity(.16) : Colors.transparent,
                              borderRadius: BorderRadius.circular(13),
                              child: ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                                leading: Icon(icons[i], color: selected ? Colors.white : Colors.white70),
                                title: Text(
                                  labels[i],
                                  style: TextStyle(
                                    color: selected ? Colors.white : Colors.white70,
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                ),
                                onTap: () => openIndex(i),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                      child: Card(
                        color: Colors.white.withOpacity(.10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.person_outline, color: Colors.white),
                          ),
                          title: Text(
                            AppData.name.split(' ').first,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text('Professor(a)', style: TextStyle(color: Colors.white70)),
                          onTap: () => openIndex(11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: IndexedStack(index: index, children: pages)),
          ],
        ),
      );
    }

    // Celular: mantém navegação simples, mas o botão Mais abre TODAS as áreas.
    final mobileIndexes = [0, 1, 2, 3, 11];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIndexes.contains(index) ? mobileIndexes.indexOf(index) : 4,
        onDestinationSelected: (value) {
          if (value == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllFeaturesPage(
                  onOpen: (i) {
                    Navigator.pop(context);
                    setState(() => index = i);
                  },
                ),
              ),
            );
          } else {
            setState(() => index = mobileIndexes[value]);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Turmas'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Recados'),
          NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Mais'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final VoidCallback onRefresh;
  const DashboardPage({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final empty = AppData.classes.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Logo(size: 34), SizedBox(width: 9), Text('EduClass', style: TextStyle(fontWeight: FontWeight.w900))]),
        actions: [
          IconButton(onPressed: () => snack(context, 'Notificações atualizadas.'), icon: const Icon(Icons.notifications_none)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          Text('Olá, ${AppData.name.split(' ').first}!', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const Text('Organize sua rotina e acompanhe seus alunos.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 18),
          if (empty)
            EmptyCard(
              icon: Icons.rocket_launch_outlined,
              title: 'Seu EduClass está pronto para começar',
              text: 'Cadastre sua primeira turma. Depois, alunos, chamadas, relatórios e horários aparecerão automaticamente.',
              button: 'Cadastrar turma',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClassPage())),
            )
          else ...[
            Row(children: [
              stat('Turmas', '${AppData.classes.length}', Icons.groups_2_outlined),
              const SizedBox(width: 10),
              stat('Alunos', '${AppData.classes.fold(0, (s, c) => s + AppData.studentsFor(c['name'] as String).length)}', Icons.people_outline),
            ]),
            Row(children: [
              stat('Eventos', '${AppData.events.length}', Icons.event_note_outlined),
              const SizedBox(width: 10),
              stat('Escolas', '${AppData.schools.length}', Icons.school_outlined),
            ]),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Próximos compromissos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  ...AppData.events.take(3).map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: primary.withOpacity(.10), child: const Icon(Icons.event, color: primary)),
                    title: Text(e['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${formatDate(e['date'] as DateTime)} • ${e['time']}'),
                  )),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 5),
          const Text('Acesso rápido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              quick(context, Icons.groups, 'Turmas', const ClassesPage()),
              quick(context, Icons.calendar_month, 'Calendário', const CalendarPage()),
              quick(context, Icons.bar_chart, 'Relatórios', const ReportsPage()),
              quick(context, Icons.edit_calendar, 'Planejar aula', const LessonPlannerPage()),
              quick(context, Icons.forum_outlined, 'Comunicação', const CommunicationPage()),
              quick(context, Icons.checklist_rounded, 'Pendências', const ActionPlanPage()),
              quick(context, Icons.lightbulb_outline, 'Ideias', const ActivityIdeasPage()),
              quick(context, Icons.auto_awesome, 'IA pedagógica', const AssistantPage()),
            ],
          ),
        ],
      ),
    );
  }

  Widget stat(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            CircleAvatar(backgroundColor: primary.withOpacity(.10), child: Icon(icon, color: primary)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(title, style: const TextStyle(color: Colors.grey)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget quick(BuildContext context, IconData icon, String label, Widget page) {
    return SizedBox(
      width: 155,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
      ),
    );
  }
}

class ClassesPage extends StatefulWidget {
  final VoidCallback? onChanged;
  const ClassesPage({super.key, this.onChanged});

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas turmas', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: add, icon: const Icon(Icons.add_circle_outline))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: add,
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar turma'),
      ),
      body: AppData.classes.isEmpty
          ? EmptyCard(
              icon: Icons.groups_outlined,
              title: 'Nenhuma turma cadastrada',
              text: 'Escolha uma turma entre 1º ano do Fundamental e 3º ano do Ensino Médio, informe o horário e pronto.',
              button: 'Cadastrar turma',
              onPressed: add,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 5, 18, 95),
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [primary, Color(0xFF7656DE)]),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text('Toque em uma turma para abrir a lista de alunos, chamada e relatórios individuais.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  ]),
                ),
                const SizedBox(height: 13),
                ...AppData.classes.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  final students = AppData.studentsFor(c['name'] as String);
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: Color(c['color'] as int).withOpacity(.12),
                        child: Text(
                          classShort(c['name'] as String),
                          style: TextStyle(color: Color(c['color'] as int), fontWeight: FontWeight.w900),
                        ),
                      ),
                      title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${students.length} alunos • ${c['day']} • ${c['time']}\n${c['room']}'),
                      isThreeLine: true,
                      trailing: PopupMenuButton(
                        onSelected: (value) {
                          if (value == 'open') openClass(c['name'] as String);
                          if (value == 'attendance') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AttendancePage(className: c['name'] as String)));
                          }
                          if (value == 'delete') {
                            setState(() => AppData.classes.removeAt(i));
                            widget.onChanged?.call();
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'open', child: Text('Abrir alunos')),
                          PopupMenuItem(value: 'attendance', child: Text('Fazer chamada')),
                          PopupMenuItem(value: 'delete', child: Text('Excluir turma')),
                        ],
                      ),
                      onTap: () => openClass(c['name'] as String),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  void openClass(String name) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ClassDetailPage(className: name)));
  }

  Future add() async {
    final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClassPage()));
    if (ok == true) {
      setState(() {});
      widget.onChanged?.call();
    }
  }
}

class AddClassPage extends StatefulWidget {
  const AddClassPage({super.key});

  @override
  State<AddClassPage> createState() => _AddClassPageState();
}

class _AddClassPageState extends State<AddClassPage> {
  String className = AppData.classOptions.first;
  final selectedDays = {'Segunda-feira'};
  String time = '08:00 - 09:40';
  String colorName = 'Roxo';
  final room = TextEditingController(text: 'Sala 01');

  final weekDays = const ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado'];
  final times = const ['07:00 - 08:40', '08:00 - 09:40', '10:00 - 11:40', '13:00 - 14:40', '14:00 - 15:40', '16:00 - 17:40', '19:00 - 20:40'];

  @override
  Widget build(BuildContext context) {
    final list = AppData.studentsFor(className);
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar turma')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Escolha a série e a turma', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('As opções vão do 1º ano do Fundamental até o 3º ano do Ensino Médio, sempre A e B.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: className,
            decoration: const InputDecoration(labelText: 'Turma / série', prefixIcon: Icon(Icons.class_outlined)),
            items: AppData.classOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setState(() => className = value!),
          ),
          const SizedBox(height: 12),
          const Text('Dias em que esta turma tem aula', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Wrap(spacing: 7, runSpacing: 7, children: weekDays.map((e) => FilterChip(
            label: Text(e.replaceAll('-feira', '')),
            selected: selectedDays.contains(e),
            onSelected: (value) => setState(() { value ? selectedDays.add(e) : selectedDays.remove(e); }),
          )).toList()),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: time,
            decoration: const InputDecoration(labelText: 'Horário', prefixIcon: Icon(Icons.access_time_outlined)),
            items: times.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (String? value) => setState(() => time = value!),
          ),
          const SizedBox(height: 12),
          TextField(controller: room, decoration: const InputDecoration(labelText: 'Sala', prefixIcon: Icon(Icons.meeting_room_outlined))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: colorName,
            decoration: const InputDecoration(labelText: 'Cor da turma', prefixIcon: Icon(Icons.palette_outlined)),
            items: const ['Roxo', 'Azul', 'Verde', 'Laranja'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (String? value) => setState(() => colorName = value!),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.people_alt_outlined, color: primary),
                  const SizedBox(width: 8),
                  Text('${list.length} alunos vinculados', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  const Text('Essa turma ainda não possui uma lista pronta. Você poderá adicionar alunos depois.', style: TextStyle(color: Colors.grey))
                else
                  ...list.take(5).map((name) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('• $name'),
                  )),
                if (list.length > 5) Text('e mais ${list.length - 5} alunos...', style: const TextStyle(color: Colors.grey)),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Cadastrar turma')),
        ],
      ),
    );
  }

  Future save() async {
    if (AppData.classes.any((c) => c['name'] == className)) {
      snack(context, 'Essa turma já está cadastrada.');
      return;
    }
    final color = switch (colorName) {
      'Azul' => 0xFF2979FF,
      'Verde' => 0xFF00A884,
      'Laranja' => 0xFFF08A24,
      _ => 0xFF0F766E,
    };
    AppData.classes.add({
      'name': className,
      'day': selectedDays.join(' • '),
      'days': selectedDays.toList(),
      'time': time,
      'room': room.text.trim().isEmpty ? 'Sala não informada' : room.text.trim(),
      'color': color,
    });
    await AppData.save();
    if (!mounted) return;
    snack(context, 'Turma cadastrada e salva.');
    Navigator.pop(context, true);
  }
}

class ClassDetailPage extends StatelessWidget {
  final String className;
  const ClassDetailPage({super.key, required this.className});

  @override
  Widget build(BuildContext context) {
    final students = AppData.studentsFor(className);
    final classData = AppData.classes.firstWhere((c) => c['name'] == className, orElse: () => {'day': '', 'time': '', 'room': ''});
    return Scaffold(
      appBar: AppBar(title: Text(className)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 5, 18, 25),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(className, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('${students.length} alunos • ${classData['day']} • ${classData['time']} • ${classData['room']}'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendancePage(className: className))), icon: const Icon(Icons.fact_check_outlined), label: const Text('Chamada'))),
                  const SizedBox(width: 9),
                  Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentReportsPage(initialClass: className))), icon: const Icon(Icons.description_outlined), label: const Text('Relatórios'))),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 5),
          Text('Alunos (${students.length})', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (students.isEmpty)
            const EmptyCard(icon: Icons.person_off_outlined, title: 'Sem alunos cadastrados', text: 'Adicione alunos para fazer chamadas e relatórios individuais.')
          else
            ...students.asMap().entries.map((entry) {
              final student = entry.value;
              final record = AppData.recordFor(className, student);
              final absence = record['absences'] as int;
              final occurrences = (record['occurrences'] as List).length;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primary.withOpacity(.10),
                    child: Text(initials(student), style: const TextStyle(color: primary, fontWeight: FontWeight.w900)),
                  ),
                  title: Text(student, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('$absence faltas • $occurrences ocorrência(s)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentReportPage(className: className, student: student))),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class AttendancePage extends StatefulWidget {
  final String className;
  const AttendancePage({super.key, required this.className});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final Map present = {};
  DateTime date = DateTime(2026, 9, 11);

  @override
  Widget build(BuildContext context) {
    final students = AppData.studentsFor(widget.className);
    for (final student in students) {
      present.putIfAbsent(student, () => true);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Chamada / Presença')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: primary),
              title: Text(widget.className, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Data: ${formatDate(date)}'),
              trailing: IconButton(
                onPressed: chooseDate,
                icon: const Icon(Icons.edit_calendar),
              ),
            ),
          ),
          Text('Presentes: ${present.values.where((e) => e).length}/${students.length}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...students.map((student) => Card(
            child: SwitchListTile(
              value: present[student] ?? true,
              onChanged: (value) => setState(() => present[student] = value),
              title: Text(student),
              subtitle: Text(present[student] == true ? 'Presente' : 'Falta'),
              secondary: Icon(present[student] == true ? Icons.check_circle : Icons.cancel, color: present[student] == true ? Colors.green : Colors.red),
            ),
          )),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: saveAttendance,
            icon: const Icon(Icons.save),
            label: const Text('Salvar chamada'),
          ),
        ],
      ),
    );
  }

  Future chooseDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2026, 12, 31),
    );
    if (d != null) setState(() => date = d);
  }

  Future saveAttendance() async {
    for (final student in present.keys) {
      final record = AppData.recordFor(widget.className, student);
      final attendance = Map.from(record['attendance'] as Map? ?? {});
      final key = formatDate(date);
      final wasAbsent = attendance[key] == false;
      final nowAbsent = present[student] == false;
      attendance[key] = !nowAbsent;
      record['attendance'] = attendance;

      var absences = record['absences'] as int;
      if (!wasAbsent && nowAbsent) {
        absences++;
      } else if (wasAbsent && !nowAbsent && absences > 0) {
        absences--;
      }
      record['absences'] = absences;
    }
    await AppData.save();
    if (!mounted) return;
    snack(context, 'Chamada salva.');
  }
}

class StudentReportsPage extends StatefulWidget {
  final String? initialClass;
  const StudentReportsPage({super.key, this.initialClass});

  @override
  State<StudentReportsPage> createState() => _StudentReportsPageState();
}

class _StudentReportsPageState extends State<StudentReportsPage> {
  late String selectedClass;
  String? selectedStudent;

  @override
  void initState() {
    super.initState();
    selectedClass = widget.initialClass ?? (AppData.classes.isNotEmpty ? AppData.classes.first['name'] as String : AppData.classOptions.first);
  }

  @override
  Widget build(BuildContext context) {
    final students = AppData.studentsFor(selectedClass);
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios dos alunos')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Selecione a turma', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
            value: selectedClass,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.groups_outlined)),
            items: (AppData.classes.isEmpty ? AppData.classOptions : AppData.classes.map((e) => e['name'] as String).toList())
                .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setState(() {
              selectedClass = value!;
              selectedStudent = null;
            }),
          ),
          const SizedBox(height: 18),
          if (students.isEmpty)
            const EmptyCard(icon: Icons.people_outline, title: 'Nenhum aluno nessa turma', text: 'As listas do 3º A e 3º B já estão preparadas. Para outras séries, adicione os alunos.')
          else ...[
            const Text('Selecione o aluno', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            DropdownButtonFormField<String>(
              value: selectedStudent,
              hint: const Text('Escolha um aluno'),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline)),
              items: students.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (String? value) => setState(() => selectedStudent = value),
            ),
            const SizedBox(height: 14),
            if (selectedStudent != null)
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentReportPage(className: selectedClass, student: selectedStudent!))),
                icon: const Icon(Icons.edit_note),
                label: const Text('Abrir relatório do aluno'),
              ),
            const SizedBox(height: 20),
            ...students.map((student) {
              final r = AppData.recordFor(selectedClass, student);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(initials(student))),
                  title: Text(student, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${r['absences']} faltas • ${(r['occurrences'] as List).length} ocorrências'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentReportPage(className: selectedClass, student: student))),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class StudentReportPage extends StatefulWidget {
  final String className;
  final String student;
  const StudentReportPage({super.key, required this.className, required this.student});

  @override
  State<StudentReportPage> createState() => _StudentReportPageState();
}

class _StudentReportPageState extends State<StudentReportPage> {
  late Map record;
  late TextEditingController notes;
  final grade = TextEditingController();
  final occurrence = TextEditingController();
  String occurrenceType = 'Pedagógica';
  int severity = 1;

  @override
  void initState() {
    super.initState();
    record = AppData.recordFor(widget.className, widget.student);
    notes = TextEditingController(text: record['notes'] as String);
  }

  @override
  void dispose() {
    notes.dispose();
    grade.dispose();
    occurrence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grades = (record['grades'] as List? ?? [])
        .map((e) => (e as num).toDouble())
        .toList();
    final occurrences = (record['occurrences'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final average = grades.isEmpty ? 0.0 : grades.reduce((a, b) => a + b) / grades.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório do aluno')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 5, 18, 25),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(children: [
                CircleAvatar(
                    radius: 32,
                    backgroundColor: primary.withOpacity(.10),
                    backgroundImage: _memoryImageFromBase64(record['studentPhoto']),
                    child: _memoryImageFromBase64(record['studentPhoto']) == null
                        ? Text(initials(widget.student), style: const TextStyle(color: primary, fontWeight: FontWeight.w900))
                        : null,
                  ),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.student, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  Text(widget.className),
                  Text('Média: ${average.toStringAsFixed(1)} • ${record['absences']} faltas', style: const TextStyle(color: Colors.grey)),
                  TextButton.icon(
                    onPressed: pickStudentPhoto,
                    icon: const Icon(Icons.camera_alt_outlined, size: 17),
                    label: const Text('Foto do aluno'),
                  ),
                ])),
              ]),
            ),
          ),
          sectionTitle('Observações sobre o aluno'),
          TextField(
            controller: notes,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Escreva desempenho, comportamento, evolução, dificuldades, participação...',
            ),
            onChanged: (value) => record['notes'] = value,
          ),
          const SizedBox(height: 18),
          sectionTitle('Notas / avaliações'),
          Row(children: [
            Expanded(child: TextField(controller: grade, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Nota (0 a 10)'))),
            const SizedBox(width: 9),
            IconButton.filled(onPressed: addGrade, icon: const Icon(Icons.add)),
          ]),
          const SizedBox(height: 8),
          if (grades.isEmpty)
            const Text('Nenhuma nota registrada.', style: TextStyle(color: Colors.grey))
          else
            Wrap(spacing: 8, children: grades.asMap().entries.map((e) => Chip(label: Text('Avaliação ${e.key + 1}: ${e.value.toStringAsFixed(1)}'))).toList()),
          const SizedBox(height: 18),
          sectionTitle('Faltas'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_busy, color: Colors.red),
              title: Text('${record['absences']} faltas registradas'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  onPressed: () async {
                    setState(() => record['absences'] = (record['absences'] as int) + 1);
                    await AppData.save();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
                IconButton(
                  onPressed: () async {
                    setState(() => record['absences'] = ((record['absences'] as int) - 1).clamp(0, 999));
                    await AppData.save();
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          sectionTitle('Ocorrências'),
          TextField(controller: occurrence, maxLines: 3, decoration: const InputDecoration(labelText: 'Descrição da ocorrência', hintText: 'Descreva o que aconteceu...')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: occurrenceType,
            decoration: const InputDecoration(labelText: 'Tipo da ocorrência'),
            items: const ['Pedagógica', 'Comportamental', 'Falta de atividade', 'Convivência', 'Outro'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (String? value) => setState(() => occurrenceType = value!),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Text('Nota da ocorrência', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Expanded(child: Slider(value: severity.toDouble(), min: 1, max: 5, divisions: 4, label: '$severity/5', onChanged: (value) => setState(() => severity = value.round()))),
            Text('$severity/5'),
          ]),
          FilledButton.icon(onPressed: addOccurrence, icon: const Icon(Icons.add_alert_outlined), label: const Text('Registrar ocorrência')),
          const SizedBox(height: 10),
          ...occurrences.map((o) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${o['score']}')),
              title: Text(o['type'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${o['text']}\nNota: ${o['score']}/5 • ${o['date']}'),
              isThreeLine: true,
            ),
          )),
          const SizedBox(height: 15),
          OutlinedButton.icon(onPressed: () { record['notes'] = notes.text; snack(context, 'Relatório salvo.'); }, icon: const Icon(Icons.save_outlined), label: const Text('Salvar relatório')),
        ],
      ),
    );
  }

  Future addGrade() async {
    final value = double.tryParse(grade.text.replaceAll(',', '.'));
    if (value == null || value < 0 || value > 10) {
      snack(context, 'Digite uma nota entre 0 e 10.');
      return;
    }
    setState(() {
      (record['grades'] as List).add(value);
      grade.clear();
    });
    await AppData.save();
  }

  Future addOccurrence() async {
    if (occurrence.text.trim().isEmpty) {
      snack(context, 'Descreva a ocorrência.');
      return;
    }
    setState(() {
      (record['occurrences'] as List).add({
        'text': occurrence.text.trim(),
        'type': occurrenceType,
        'score': severity,
        'date': formatDate(DateTime.now()),
      });
      occurrence.clear();
    });
    await AppData.save();
    if (!mounted) return;
    snack(context, 'Ocorrência registrada e salva.');
  }

  Future pickStudentPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1000,
    );
    if (file == null) return;
    record['studentPhoto'] = base64Encode(await file.readAsBytes());
    await AppData.save();
    if (!mounted) return;
    setState(() {});
    snack(context, 'Foto do aluno salva.');
  }

  Widget sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
  );
}

class CalendarPage extends StatefulWidget {
  final VoidCallback? onChanged;
  const CalendarPage({super.key, this.onChanged});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime month = DateTime(2026, 9, 1);
  DateTime selected = DateTime(2026, 9, 11);

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday % 7;
    final dayEvents = eventsFor(selected);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário 2026', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: addEvent, icon: const Icon(Icons.add_circle_outline))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEvent,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 5, 18, 95),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton(onPressed: previousMonth, icon: const Icon(Icons.chevron_left)),
                  Text('${monthName(month.month)} ${month.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  IconButton(onPressed: nextMonth, icon: const Icon(Icons.chevron_right)),
                ]),
                const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  Text('D'), Text('S'), Text('T'), Text('Q'), Text('Q'), Text('S'), Text('S'),
                ]),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: offset + days,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                  itemBuilder: (_, index) {
                    final d = index - offset + 1;
                    if (d < 1) return const SizedBox();
                    final date = DateTime(month.year, month.month, d);
                    final active = sameDay(date, selected);
                    final holiday = holidayFor(date);
                    final has = eventsFor(date).isNotEmpty || classEventsFor(date).isNotEmpty;
                    return GestureDetector(
                      onTap: () => setState(() => selected = date),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: active ? primary : null),
                        child: Stack(alignment: Alignment.center, children: [
                          Text('$d', style: TextStyle(color: active ? Colors.white : holiday != null ? Colors.red : null, fontWeight: active || holiday != null ? FontWeight.w900 : null)),
                          if (has) Positioned(bottom: 2, child: Container(width: 5, height: 5, decoration: BoxDecoration(color: active ? Colors.white : primary, shape: BoxShape.circle))),
                        ]),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${selected.day} de ${monthName(selected.month)}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                if (holidayFor(selected) != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(backgroundColor: Color(0xFFFFE6E6), child: Icon(Icons.flag, color: Colors.red)),
                    title: Text(holidayFor(selected)!['title']!, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Feriado'),
                  ),
                ...classEventsFor(selected).map((e) => eventTile(e, locked: true)),
                ...dayEvents.map((e) => eventTile(e)),
                if (holidayFor(selected) == null && dayEvents.isEmpty && classEventsFor(selected).isEmpty)
                  const Padding(padding: EdgeInsets.all(10), child: Text('Nenhum compromisso neste dia.', style: TextStyle(color: Colors.grey))),
              ]),
            ),
          ),
          const SizedBox(height: 7),
          OutlinedButton.icon(onPressed: addEvent, icon: const Icon(Icons.add), label: const Text('Adicionar reunião, conselho, avaliação ou outro evento')),
        ],
      ),
    );
  }

  Widget eventTile(Map e, {bool locked = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: primary.withOpacity(.10), child: Icon(iconForType(e['type'] as String), color: primary)),
      title: Text(e['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${e['time']} • ${e['type']}\n${e['school']}\n${e['description']}'),
      isThreeLine: true,
      trailing: locked ? null : IconButton(onPressed: () { setState(() => AppData.events.remove(e)); widget.onChanged?.call(); }, icon: const Icon(Icons.delete_outline)),
    );
  }

  List<Map<String, dynamic>> classEventsFor(DateTime date) {
    final day = weekdayName(date.weekday);
    return AppData.classes.where((c) {
      final raw = c['days'];
      if (raw is List) return raw.map((e) => e.toString()).contains(day);
      return c['day'] == day;
    }).map((c) => {
      'date': date,
      'title': 'Aula • ${c['name']}',
      'type': 'Aula',
      'time': c['time'],
      'school': AppData.school,
      'description': c['room'],
    }).toList();
  }

  List<Map<String, dynamic>> eventsFor(DateTime date) {
    return AppData.events.where((e) => sameDay(e['date'] as DateTime, date)).toList();
  }

  String weekdayName(int weekday) {
    const days = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];
    return days[weekday - 1];
  }

  void previousMonth() {
    setState(() {
      month = DateTime(month.year, month.month - 1, 1);
      selected = DateTime(month.year, month.month, 1);
    });
  }

  void nextMonth() {
    setState(() {
      month = DateTime(month.year, month.month + 1, 1);
      selected = DateTime(month.year, month.month, 1);
    });
  }

  Future addEvent() async {
    final ok = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddEventSheet(initialDate: selected),
    );
    if (ok == true) {
      setState(() {});
      widget.onChanged?.call();
    }
  }
}

class AddEventSheet extends StatefulWidget {
  final DateTime initialDate;
  const AddEventSheet({super.key, required this.initialDate});

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  final title = TextEditingController();
  final time = TextEditingController(text: '14:00 - 15:00');
  final description = TextEditingController();
  DateTime date = DateTime(2026, 9, 11);
  String type = 'Reunião';
  String school = AppData.school;

  final types = const ['Reunião', 'Conselho', 'Avaliação', 'Atividade', 'Evento escolar', 'Outro'];

  @override
  void initState() {
    super.initState();
    date = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Novo compromisso', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Título', prefixIcon: Icon(Icons.event_note_outlined))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: types.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setState(() => type = value!),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data'),
            subtitle: Text(formatDate(date)),
            trailing: IconButton(
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2026, 1, 1), lastDate: DateTime(2026, 12, 31));
                if (d != null) setState(() => date = d);
              },
              icon: const Icon(Icons.calendar_month),
            ),
          ),
          TextField(controller: time, decoration: const InputDecoration(labelText: 'Horário', prefixIcon: Icon(Icons.access_time))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: AppData.schools.contains(school) ? school : (AppData.schools.isNotEmpty ? AppData.schools.first : null),
            decoration: const InputDecoration(labelText: 'Escola'),
            items: AppData.schools.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (String? value) => setState(() => school = value!),
          ),
          const SizedBox(height: 10),
          TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Detalhes / observações')),
          const SizedBox(height: 15),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: const Text('Salvar no calendário'))),
        ]),
      ),
    );
  }

  Future save() async {
    if (title.text.trim().isEmpty) {
      snack(context, 'Informe um título.');
      return;
    }
    AppData.events.add({
      'date': date,
      'title': title.text.trim(),
      'type': type,
      'time': time.text.trim().isEmpty ? 'Dia todo' : time.text.trim(),
      'school': school,
      'description': description.text.trim().isEmpty ? 'Compromisso escolar.' : description.text.trim(),
    });
    await AppData.save();
    if (!mounted) return;
    Navigator.pop(context, true);
  }
}

class SchoolsPage extends StatefulWidget {
  const SchoolsPage({super.key});

  @override
  State<SchoolsPage> createState() => _SchoolsPageState();
}

class _SchoolsPageState extends State<SchoolsPage> {
  final school = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas escolas')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Você pode trabalhar com mais de uma escola.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Use a escola nos eventos do calendário para saber onde cada reunião ou conselho acontece.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ...AppData.schools.map((s) => Card(child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFEDE7FF), child: Icon(Icons.school, color: primary)),
            title: Text(s, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(s == AppData.school ? 'Escola principal' : 'Escola vinculada'),
            trailing: s == AppData.school ? const Icon(Icons.star, color: primary) : IconButton(onPressed: () => setState(() => AppData.schools.remove(s)), icon: const Icon(Icons.delete_outline)),
          ))),
          const SizedBox(height: 12),
          TextField(controller: school, decoration: const InputDecoration(labelText: 'Nome da nova escola', prefixIcon: Icon(Icons.add_business_outlined))),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: addSchool, icon: const Icon(Icons.add), label: const Text('Adicionar escola')),
        ],
      ),
    );
  }

  Future addSchool() async {
    final value = school.text.trim();
    if (value.isEmpty) {
      snack(context, 'Digite o nome da escola.');
      return;
    }
    if (AppData.schools.contains(value)) {
      snack(context, 'Essa escola já está cadastrada.');
      return;
    }
    setState(() {
      AppData.schools.add(value);
      school.clear();
    });
    await AppData.save();
  }
}

class WellBeingPage extends StatelessWidget {
  const WellBeingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bem-estar', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Como você está hoje?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  mood(context, 'Bem', '🙂'),
                  mood(context, 'Mais ou menos', '😐'),
                  mood(context, 'Preciso de ajuda', '☹️'),
                ]),
              ]),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFEDE7FF), child: Icon(Icons.chat_bubble_outline, color: primary)),
              title: const Text('Converse com o Apoio EduClass', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('Um espaço de acolhimento para conversar sobre ansiedade, cansaço, sobrecarga, tristeza e outros momentos difíceis.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WellBeingChatPage())),
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Lembrete importante', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('O Apoio EduClass é um recurso de acolhimento e não substitui psicólogo, médico ou outro profissional de saúde. Quando precisar, procure ajuda profissional.'),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget mood(BuildContext context, String text, String emoji) {
    return InkWell(
      onTap: () => snack(context, 'Humor registrado: $text.'),
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [Text(emoji, style: const TextStyle(fontSize: 31)), const SizedBox(height: 4), Text(text, style: const TextStyle(fontSize: 11))]),
      ),
    );
  }
}

class WellBeingChatPage extends StatefulWidget {
  const WellBeingChatPage({super.key});

  @override
  State<WellBeingChatPage> createState() => _WellBeingChatPageState();
}

class _WellBeingChatPageState extends State<WellBeingChatPage> {
  final controller = TextEditingController();
  final scroll = ScrollController();
  final List<Map<String, String>> messages = [
    {'from': 'bot', 'text': 'Oi! Eu sou o Apoio EduClass. Pode conversar comigo. Como você está se sentindo hoje?'},
  ];

  final suggestions = const [
    'Estou ansiosa',
    'Estou cansada',
    'Estou sobrecarregada',
    'Quero desabafar',
    'Estou triste',
    'Estou com dificuldade para dormir',
    'Estou com problemas na escola',
    'Preciso falar com um profissional',
    'Quero organizar minha cabeça',
    'Estou com medo',
  ];

  String answer(String input) {
    final t = input.toLowerCase();
    if (t.contains('profissional') || t.contains('psicólogo') || t.contains('psicologo')) {
      return 'Buscar um psicólogo ou outro profissional pode ser uma ótima decisão. Se você já tem alguém de confiança, considere entrar em contato. Se não tiver, procure os canais de atendimento da sua escola, unidade de saúde ou serviço profissional da sua região.';
    }
    if (containsAny(t, ['ansiosa', 'ansioso', 'ansiedade', 'nervosa', 'crise'])) {
      return 'Vamos com calma. Tente inspirar pelo nariz por 4 segundos e soltar o ar por 6. Depois, me conte: o que aconteceu antes de você começar a se sentir assim? Se a ansiedade estiver frequente ou difícil de controlar, procure um profissional.';
    }
    if (containsAny(t, ['cansada', 'cansado', 'exausta', 'exausto', 'esgotada', 'esgotado'])) {
      return 'Você parece estar precisando de espaço para respirar. O que está mais pesado hoje: aulas, alunos, prazos, casa ou tudo ao mesmo tempo? Se isso estiver persistente, conversar com um profissional pode ajudar.';
    }
    if (containsAny(t, ['sobrecarregada', 'sobrecarregado', 'sobrecarga', 'estressada', 'estressado', 'pressão', 'pressao'])) {
      return 'Quando tudo parece urgente, tente dividir em três grupos: preciso fazer hoje, pode esperar e posso pedir ajuda. Se quiser, escreva aqui tudo que está pesando e eu te ajudo a organizar. Se essa sobrecarga estiver constante ou muito intensa, procure um profissional de saúde.';
    }
    if (containsAny(t, ['desabafar', 'falar', 'contar'])) {
      return 'Pode desabafar. Eu vou te ouvir sem julgamentos. Comece pela parte que mais está incomodando agora, mesmo que pareça confusa.';
    }
    if (containsAny(t, ['triste', 'tristeza', 'chorar', 'sozinha', 'sozinho'])) {
      return 'Sinto muito que você esteja passando por isso. Se puder, procure alguém de confiança para não carregar tudo sozinha. Se quiser, pode me contar o que aconteceu.';
    }
    if (containsAny(t, ['dormir', 'sono', 'insônia', 'insonia'])) {
      return 'Uma rotina mais tranquila antes de dormir pode ajudar: diminua estímulos, tente manter um horário regular e anote preocupações para lidar com elas depois. Se a dificuldade persistir, vale conversar com um profissional.';
    }
    if (containsAny(t, ['escola', 'aluno', 'alunos', 'professor', 'aula'])) {
      return 'A rotina escolar pode pesar bastante. Me conte qual situação está acontecendo com a escola ou com os alunos e vamos separar o problema em partes.';
    }
    if (containsAny(t, ['medo', 'assustada', 'assustado'])) {
      return 'Entendo. Primeiro, veja se você está em um lugar seguro. Se estiver, respire devagar e me conte do que você está com medo. Se houver perigo imediato, procure ajuda presencial e os serviços de emergência da sua região.';
    }
    return 'Estou te ouvindo. Pode explicar um pouco mais? Se preferir, comece dizendo o que aconteceu, como você se sente e o que gostaria que mudasse.';
  }

  void send([String? preset]) {
    final text = (preset ?? controller.text).trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add({'from': 'user', 'text': text});
      messages.add({'from': 'bot', 'text': answer(text)});
    });
    controller.clear();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Apoio EduClass', style: TextStyle(fontWeight: FontWeight.w900)),
          Text('Espaço de acolhimento', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 8),
            itemCount: messages.length,
            itemBuilder: (_, i) {
              final m = messages[i];
              final user = m['from'] == 'user';
              return Align(
                alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(13),
                  constraints: const BoxConstraints(maxWidth: 340),
                  decoration: BoxDecoration(
                    color: user ? primary.withOpacity(.10) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primary.withOpacity(.10)),
                  ),
                  child: Text(m['text']!),
                ),
              );
            },
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ActionChip(label: Text(s), onPressed: () => send(s)),
            )).toList(),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 12),
            child: Row(children: [
              Expanded(child: TextField(controller: controller, onSubmitted: (_) => send(), decoration: const InputDecoration(hintText: 'Digite como você está se sentindo...'))),
              const SizedBox(width: 7),
              IconButton.filled(onPressed: send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final controller = TextEditingController();
  final List<Map<String, String>> messages = [
    {'from': 'bot', 'text': 'Olá! Sou a IA pedagógica do EduClass. Posso ajudar com atividades, planos de aula, avaliações e organização.'},
  ];

  void send([String? preset]) {
    final text = (preset ?? controller.text).trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add({'from': 'user', 'text': text});
      messages.add({'from': 'bot', 'text': 'Posso transformar isso em uma sugestão prática de aula. Para começar, diga a turma, a matéria e o objetivo da atividade.'});
    });
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IA Pedagógica')),
      body: Column(children: [
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final user = messages[i]['from'] == 'user';
            return Align(
              alignment: user ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(13),
                constraints: const BoxConstraints(maxWidth: 330),
                decoration: BoxDecoration(color: user ? primary.withOpacity(.10) : Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Text(messages[i]['text']!),
              ),
            );
          },
        )),
        SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: TextField(controller: controller, onSubmitted: (_) => send(), decoration: const InputDecoration(hintText: 'Ex.: crie uma atividade para o 3º ano'))),
          const SizedBox(width: 7),
          IconButton.filled(onPressed: send, icon: const Icon(Icons.send)),
        ]))),
      ]),
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      {'label': 'Presença', 'value': 88.0},
      {'label': 'Atividades', 'value': 76.0},
      {'label': 'Avaliações', 'value': 82.0},
      {'label': 'Participação', 'value': 91.0},
      {'label': 'Entregas', 'value': 68.0},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios inteligentes')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [primary, secondary]), borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Visão geral pedagógica', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('Acompanhe indicadores da rotina sem precisar montar planilhas.', style: TextStyle(color: Colors.white70))])),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: metricCard('8,6', 'Média geral', Icons.school_outlined)), const SizedBox(width: 10), Expanded(child: metricCard('92%', 'Frequência', Icons.event_available)), const SizedBox(width: 10), Expanded(child: metricCard('74%', 'Entregas', Icons.task_alt))]),
        const SizedBox(height: 20),
        const Text('Indicadores da turma', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 10), child: Column(children: data.map((d) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [SizedBox(width: 92, child: Text(d['label'] as String, style: const TextStyle(fontWeight: FontWeight.w700))), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(minHeight: 12, value: (d['value'] as double) / 100, backgroundColor: primary.withOpacity(.08)))), const SizedBox(width: 10), Text('${(d['value'] as double).round()}%', style: const TextStyle(fontWeight: FontWeight.w900))]))).toList()))),
        const SizedBox(height: 18),
        const Text('Relatórios por turma', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
        ...AppData.classes.map((c) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: primary.withOpacity(.10), child: const Icon(Icons.groups, color: primary)), title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${AppData.studentsFor(c['name'] as String).length} alunos • ${c['day']}'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentReportsPage(initialClass: c['name'] as String)))))),
        if (AppData.classes.isEmpty) const EmptyCard(icon: Icons.bar_chart_outlined, title: 'Sem turmas', text: 'Cadastre uma turma para gerar relatórios.'),
      ]),
    );
  }

  static Widget metricCard(String value, String label, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: primary), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))])));
}


class MorePage extends StatelessWidget {
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onChanged;

  const MorePage({super.key, required this.onThemeChanged, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, dynamic>>[
      {'icon': Icons.person_outline, 'title': 'Meu perfil', 'page': const GoogleAccountPage()},
      {'icon': Icons.description_outlined, 'title': 'Relatórios dos alunos', 'page': const StudentReportsPage()},
      {'icon': Icons.bar_chart_outlined, 'title': 'Visão geral de relatórios', 'page': const ReportsPage()},
      {'icon': Icons.school_outlined, 'title': 'Minhas escolas', 'page': const SchoolsPage()},
      {'icon': Icons.auto_awesome, 'title': 'IA pedagógica', 'page': const AssistantPage()},
      {'icon': Icons.edit_calendar_outlined, 'title': 'Planejamento de aulas', 'page': const LessonPlannerPage()},
      {'icon': Icons.forum_outlined, 'title': 'Recados e comunicação', 'page': const CommunicationPage()},
      {'icon': Icons.checklist_rounded, 'title': 'Pendências e plano de ação', 'page': const ActionPlanPage()},
      {'icon': Icons.lightbulb_outline, 'title': 'Banco de ideias', 'page': const ActivityIdeasPage()},
      {'icon': Icons.ondemand_video_outlined, 'title': 'Videoaulas por matéria', 'page': const VideoLessonsPage()},
      {'icon': Icons.science_outlined, 'title': 'Artigos científicos', 'page': const ScientificArticlesPage()},
      {'icon': Icons.groups_2_outlined, 'title': 'Reuniões', 'page': const MeetingsPage()},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mais', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          ProfileHeader(onChanged: onChanged),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0B5960), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.apps_outlined, color: Colors.white, size: 29),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Todas as ferramentas do EduClass ficam reunidas aqui para você encontrar tudo sem depender de um botão “Mais” escondendo funções.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Card(
              child: ListTile(
                leading: Icon(item['icon'] as IconData, color: primary),
                title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['page'] as Widget)),
              ),
            ),
          ),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Tema escuro'),
              subtitle: const Text('Alternar aparência'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: onThemeChanged,
            ),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: () async {
              await AppData.save();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginPage(onThemeChanged: onThemeChanged)),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ProfileHeader extends StatefulWidget {
  final VoidCallback onChanged;
  const ProfileHeader({super.key, required this.onChanged});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  final picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: const Color(0xFFEDE7FF),
              backgroundImage: _memoryImageFromBase64(AppData.profilePhotoBase64),
              child: _memoryImageFromBase64(AppData.profilePhotoBase64) == null ? const Icon(Icons.person, size: 40, color: primary) : null,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: IconButton.filledTonal(onPressed: pickPhoto, icon: const Icon(Icons.camera_alt, size: 17)),
            ),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppData.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('Professor(a) de ${AppData.subject}'),
            Text(AppData.school, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            TextButton.icon(onPressed: pickPhoto, icon: const Icon(Icons.photo_camera_outlined, size: 17), label: const Text('Alterar foto')),
          ])),
        ]),
      ),
    );
  }

  Future pickPhoto() async {
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1000,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      AppData.profilePhoto = file;
      AppData.profilePhotoBase64 = base64Encode(bytes);
    });
    await AppData.save();
    widget.onChanged();
  }
}

ImageProvider<Object>? _memoryImageFromBase64(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  try {
    final bytes = base64Decode(raw);
    return MemoryImage(Uint8List.fromList(bytes));
  } catch (_) {
    return null;
  }
}

class EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String? button;
  final VoidCallback? onPressed;
  const EmptyCard({super.key, required this.icon, required this.title, required this.text, this.button, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          CircleAvatar(radius: 32, backgroundColor: primary.withOpacity(.10), child: Icon(icon, size: 32, color: primary)),
          const SizedBox(height: 13),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          if (button != null) ...[
            const SizedBox(height: 15),
            FilledButton(onPressed: onPressed, child: Text(button!)),
          ],
        ]),
      ),
    );
  }
}

bool containsAny(String value, List<String> words) {
  return words.any((word) => value.contains(word));
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

Map? holidayFor(DateTime date) {
  final key = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  for (final holiday in AppData.holidays) {
    if (holiday['date'] == key) return holiday;
  }
  return null;
}

String formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String monthName(int month) {
  const names = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
  return names[month - 1];
}

IconData iconForType(String type) {
  switch (type) {
    case 'Reunião':
      return Icons.groups_2_outlined;
    case 'Conselho':
      return Icons.gavel_outlined;
    case 'Avaliação':
      return Icons.assignment_outlined;
    case 'Atividade':
      return Icons.task_alt_outlined;
    case 'Evento escolar':
      return Icons.celebration_outlined;
    case 'Aula':
      return Icons.menu_book_outlined;
    default:
      return Icons.event_outlined;
  }
}

String classShort(String name) {
  if (name.contains('3º Ano Ensino Médio A')) return '3A';
  if (name.contains('3º Ano Ensino Médio B')) return '3B';
  final parts = name.split(' ');
  return parts.length >= 2 ? parts[0].replaceAll('º', '') : 'T';
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'U';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}

void snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class LessonPlannerPage extends StatefulWidget {
  final VoidCallback? onChanged;
  const LessonPlannerPage({super.key, this.onChanged});

  @override
  State<LessonPlannerPage> createState() => _LessonPlannerPageState();
}

class _LessonPlannerPageState extends State<LessonPlannerPage> {
  final title = TextEditingController();
  final theme = TextEditingController();
  final objective = TextEditingController();
  String subject = AppData.selectedSubjects.isNotEmpty ? AppData.selectedSubjects.first : 'Matemática';
  String className = AppData.classes.isNotEmpty ? AppData.classes.first['name'] as String : 'Minha turma';
  DateTime date = DateTime.now();
  String time = '08:00 - 09:40';

  @override
  void dispose() {
    title.dispose();
    theme.dispose();
    objective.dispose();
    super.dispose();
  }

  Future save() async {
    if (title.text.trim().isEmpty || theme.text.trim().isEmpty) {
      snack(context, 'Informe o título e o tema da aula.');
      return;
    }
    AppData.lessonPlans.add({
      'title': title.text.trim(),
      'theme': theme.text.trim(),
      'objective': objective.text.trim(),
      'subject': subject,
      'class': className,
      'date': date.toIso8601String(),
      'time': time,
    });
    AppData.pendingTasks.remove('Planejar a primeira aula');
    await AppData.save();
    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call();
    snack(context, 'Plano de aula salvo com sucesso.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planejar aula')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(color: primary.withOpacity(.08), borderRadius: BorderRadius.circular(18)),
            child: const Row(children: [
              Icon(Icons.auto_awesome, color: primary),
              SizedBox(width: 10),
              Expanded(child: Text('Monte uma aula completa e salve para organizar sua grade.')),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Título da aula', prefixIcon: Icon(Icons.title))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: AppData.selectedSubjects.contains(subject) ? subject : (AppData.selectedSubjects.isNotEmpty ? AppData.selectedSubjects.first : null),
            decoration: const InputDecoration(labelText: 'Matéria', prefixIcon: Icon(Icons.menu_book_outlined)),
            items: AppData.selectedSubjects.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (String? v) => setState(() => subject = v!),
          ),
          const SizedBox(height: 12),
          TextField(controller: theme, decoration: const InputDecoration(labelText: 'Tema / conteúdo', prefixIcon: Icon(Icons.topic_outlined))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: className,
            decoration: const InputDecoration(labelText: 'Turma'),
            items: [...AppData.classes.map((e) => e['name'] as String), 'Minha turma'].toSet().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => className = v!),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dia da aula', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(formatDate(date)),
            trailing: IconButton(
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2026, 1, 1), lastDate: DateTime(2027, 12, 31));
                if (d != null) setState(() => date = d);
              },
              icon: const Icon(Icons.calendar_month),
            ),
          ),
          TextField(controller: objective, maxLines: 3, decoration: const InputDecoration(labelText: 'Objetivo de aprendizagem', prefixIcon: Icon(Icons.flag_outlined))),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Salvar plano de aula')),
          const SizedBox(height: 20),
          if (AppData.lessonPlans.isNotEmpty) ...[
            const Text('Planos salvos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...AppData.lessonPlans.map((p) => Card(
              child: ListTile(
                title: Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p['subject']} • ${p['class']}\nTema: ${p['theme']}'),
                isThreeLine: true,
              ),
            )),
          ],
        ],
      ),
    );
  }
}


class CommunicationPage extends StatefulWidget {
  const CommunicationPage({super.key});

  @override
  State<CommunicationPage> createState() => _CommunicationPageState();
}

class _CommunicationPageState extends State<CommunicationPage> {
  final messageController = TextEditingController();
  String? selectedClass;
  String? selectedStudent;

  final templates = const [
    {
      'title': 'Marcar reunião',
      'text': 'Olá! Gostaria de marcar uma reunião para conversarmos sobre o acompanhamento do aluno.'
    },
    {
      'title': 'Falar com responsável',
      'text': 'Olá! Preciso falar com o responsável do aluno {aluno}, da turma {turma}, para conversarmos sobre o acompanhamento escolar.'
    },
    {
      'title': 'Aviso para a turma',
      'text': 'Olá, turma {turma}! Passando para lembrar que temos uma atividade importante nesta semana.'
    },
    {
      'title': 'Solicitar apoio pedagógico',
      'text': 'Olá! Gostaria de solicitar apoio da coordenação para uma situação pedagógica da turma {turma}.'
    },
    {
      'title': 'Enviar atividade',
      'text': 'Olá! A atividade da turma {turma} já está disponível. Por favor, verifiquem as orientações e o prazo de entrega.'
    },
    {
      'title': 'Registrar ausência',
      'text': 'Olá! Gostaria de registrar uma ausência e alinhar os próximos passos com a coordenação.'
    },
  ];

  String buildTemplate(String value) {
    return value
        .replaceAll('{turma}', selectedClass ?? 'turma')
        .replaceAll('{aluno}', selectedStudent ?? 'aluno');
  }

  Future send() async {
    final text = messageController.text.trim();
    if (text.isEmpty) {
      snack(context, 'Escolha uma mensagem ou escreva um recado.');
      return;
    }
    setState(() {
      AppData.communications.add({
        'text': text,
        'date': formatDate(DateTime.now()),
        'class': selectedClass ?? 'Geral',
        'student': selectedStudent ?? '',
      });
      messageController.clear();
    });
    await AppData.save();
    if (!mounted) return;
    snack(context, 'Mensagem preparada e registrada.');
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classes = AppData.classes.map((e) => e['name'] as String).toList();
    final students = selectedClass == null ? <String>[] : AppData.studentsFor(selectedClass!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recados e Comunicação', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0B5960), Color(0xFF1A8B8A), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.forum_outlined, color: Colors.white, size: 30),
                SizedBox(height: 10),
                Text('Central de recados', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('Escolha uma mensagem pronta, personalize e envie para a pessoa ou turma certa.', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('1. Para quem é o recado?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedClass,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Turma', prefixIcon: Icon(Icons.groups_outlined)),
            hint: const Text('Selecione a turma'),
            items: classes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() {
              selectedClass = v;
              selectedStudent = null;
            }),
          ),
          if (selectedClass != null) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedStudent,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Aluno (opcional)', prefixIcon: Icon(Icons.person_outline)),
              hint: const Text('Selecione um aluno'),
              items: students.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => selectedStudent = v),
            ),
          ],
          const SizedBox(height: 20),
          const Text('2. Mensagens prontas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...templates.map(
            (t) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE5F4F2),
                  child: Icon(Icons.bolt_outlined, color: primary),
                ),
                title: Text(t['title']!, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(buildTemplate(t['text']!), maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => setState(() => messageController.text = buildTemplate(t['text']!)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('3. Mensagem', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TextField(
            controller: messageController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Edite a mensagem antes de enviar...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: messageController.text));
                    if (mounted) snack(context, 'Mensagem copiada. Agora você pode colar no canal de envio.');
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copiar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: send,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Registrar envio'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Histórico recente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (AppData.communications.isEmpty)
            const EmptyCard(icon: Icons.mark_unread_chat_alt_outlined, title: 'Nenhum recado ainda', text: 'As mensagens registradas aparecerão aqui.')
          else
            ...AppData.communications.reversed.take(8).map(
              (item) => Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: primary),
                  title: Text(item['text'] ?? ''),
                  subtitle: Text('${item['class'] ?? 'Geral'} • ${item['date'] ?? ''}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ActionPlanPage extends StatefulWidget {
  const ActionPlanPage({super.key});

  @override
  State<ActionPlanPage> createState() => _ActionPlanPageState();
}

class _ActionPlanPageState extends State<ActionPlanPage> {
  final titleController = TextEditingController();

  Future addTask() async {
    if (titleController.text.trim().isEmpty) return;
    setState(() {
      AppData.pendingTasks.add(titleController.text.trim());
      titleController.clear();
    });
    await AppData.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pendências e Plano de Ação')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: titleController,
                  decoration: const InputDecoration(hintText: 'Nova pendência...'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: addTask, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Lista de Tarefas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...AppData.pendingTasks.map((task) => Card(
            child: ListTile(
              leading: const Icon(Icons.check_box_outline_blank, color: primary),
              title: Text(task),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  setState(() => AppData.pendingTasks.remove(task));
                  await AppData.save();
                },
              ),
            ),
          )),
        ],
      ),
    );
  }
}


class ActivityIdeasPage extends StatefulWidget {
  const ActivityIdeasPage({super.key});

  @override
  State<ActivityIdeasPage> createState() => _ActivityIdeasPageState();
}

class _ActivityIdeasPageState extends State<ActivityIdeasPage> {
  final search = TextEditingController();
  String category = 'Todas';

  final ideas = const [
    {'title':'Quiz relâmpago','category':'Avaliação','desc':'5 perguntas rápidas no início da aula para descobrir o que a turma já sabe.','icon':Icons.quiz_outlined},
    {'title':'Roda de conversa','category':'Interação','desc':'Comece com uma pergunta-problema e deixe os alunos construírem hipóteses.','icon':Icons.forum_outlined},
    {'title':'Estudo de caso','category':'Projeto','desc':'Apresente um problema real e peça que grupos proponham soluções.','icon':Icons.cases_outlined},
    {'title':'Mapa mental coletivo','category':'Revisão','desc':'Monte um mapa no quadro e peça que cada grupo acrescente um conceito.','icon':Icons.account_tree_outlined},
    {'title':'Sala invertida','category':'Metodologia','desc':'Envie um conteúdo curto antes da aula e use o encontro para prática e discussão.','icon':Icons.flip_to_front_outlined},
    {'title':'Experimento simples','category':'Prática','desc':'Transforme o conteúdo em uma pequena experiência com materiais acessíveis.','icon':Icons.science_outlined},
    {'title':'Debate com papéis','category':'Interação','desc':'Distribua papéis e argumentos para organizar um debate com objetivos claros.','icon':Icons.record_voice_over_outlined},
    {'title':'Caça ao erro','category':'Revisão','desc':'Mostre uma resolução com erros e desafie a turma a encontrar e corrigir.','icon':Icons.search_off_outlined},
    {'title':'Produção de podcast','category':'Projeto','desc':'Grupos explicam um conteúdo em um roteiro curto de áudio.','icon':Icons.podcasts_outlined},
    {'title':'Bingo de conceitos','category':'Revisão','desc':'Use conceitos da matéria nas cartelas e revise de forma divertida.','icon':Icons.grid_3x3_outlined},
    {'title':'Linha do tempo','category':'História','desc':'Organize acontecimentos e peça aos alunos que justifiquem a ordem.','icon':Icons.timeline_outlined},
    {'title':'Desafio de programação','category':'Tecnologia','desc':'Proponha um pequeno problema e deixe a turma criar, testar e melhorar a solução.','icon':Icons.code_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    final cats = ['Todas', ...ideas.map((e) => e['category'] as String).toSet()];
    final q = search.text.toLowerCase();
    final filtered = ideas.where((e) {
      final okCat = category == 'Todas' || e['category'] == category;
      final okText = '${e['title']} ${e['desc']}'.toLowerCase().contains(q);
      return okCat && okText;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Banco de Ideias', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0B5960), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(23),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.white, size: 31),
                SizedBox(height: 9),
                Text('Ideias para sua próxima aula', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('Pesquise, filtre e abra uma ideia para adaptar ao seu conteúdo.', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Pesquisar ideia, atividade ou metodologia'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: cats.map((c) => Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(label: Text(c), selected: category == c, onSelected: (_) => setState(() => category = c)),
              )).toList(),
            ),
          ),
          const SizedBox(height: 14),
          ...filtered.map(
            (e) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(13),
                leading: CircleAvatar(
                  backgroundColor: primary.withOpacity(.10),
                  child: Icon(e['icon'] as IconData, color: primary),
                ),
                title: Text(e['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(e['desc'] as String),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(e['title'] as String),
                    content: Text(e['desc'] as String),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
                  ),
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            const EmptyCard(icon: Icons.search_off, title: 'Nada encontrado', text: 'Tente outro termo ou escolha a categoria Todas.'),
        ],
      ),
    );
  }
}


class VideoLessonsPage extends StatefulWidget {
  const VideoLessonsPage({super.key});

  @override
  State<VideoLessonsPage> createState() => _VideoLessonsPageState();
}

class _VideoLessonsPageState extends State<VideoLessonsPage>
    with SingleTickerProviderStateMixin {
  final controller = TextEditingController();
  String subject = '';
  late final TabController tabs;

  final catalog = const <String, List<List<String>>>{
    'matemática': [
      ['Khan Academy Brasil — Matemática', 'https://www.youtube.com/@KhanAcademyBrasil'],
      ['Matemática Rio — aulas e exercícios', 'https://www.youtube.com/@MatematicaRio'],
      ['Equações e funções — busca de aulas', 'https://www.youtube.com/results?search_query=equacoes+funcoes+matematica'],
    ],
    'português': [
      ['Português — gramática e interpretação', 'https://www.youtube.com/results?search_query=portugues+gramatica+interpretacao'],
      ['Literatura brasileira — aulas', 'https://www.youtube.com/results?search_query=literatura+brasileira+aulas'],
    ],
    'história': [
      ['História do Brasil — aulas', 'https://www.youtube.com/results?search_query=historia+do+brasil+aulas'],
      ['História geral — revisão', 'https://www.youtube.com/results?search_query=historia+geral+aulas'],
    ],
    'geografia': [
      ['Geografia — aulas e revisão', 'https://www.youtube.com/results?search_query=geografia+aulas'],
      ['Geopolítica — aulas', 'https://www.youtube.com/results?search_query=geopolitica+aulas'],
    ],
    'biologia': [
      ['Biologia — aulas e revisão', 'https://www.youtube.com/results?search_query=biologia+aulas'],
      ['Genética — revisão', 'https://www.youtube.com/results?search_query=genetica+aulas'],
    ],
    'química': [
      ['Química — aulas e exercícios', 'https://www.youtube.com/results?search_query=quimica+aulas+exercicios'],
      ['Química orgânica — revisão', 'https://www.youtube.com/results?search_query=quimica+organica+aulas'],
    ],
    'física': [
      ['Física — aulas e exercícios', 'https://www.youtube.com/results?search_query=fisica+aulas+exercicios'],
      ['Mecânica — revisão', 'https://www.youtube.com/results?search_query=mecanica+fisica+aulas'],
    ],
    'inglês': [
      ['Inglês — aulas e conversação', 'https://www.youtube.com/results?search_query=ingles+aulas+conversacao'],
      ['Gramática inglesa — revisão', 'https://www.youtube.com/results?search_query=gramatica+inglesa+aulas'],
    ],
  };

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    tabs.dispose();
    super.dispose();
  }

  List<List<String>> results() {
    final q = subject.trim().toLowerCase();
    if (q.isEmpty) return [];

    for (final key in catalog.keys) {
      if (q.contains(key) || key.contains(q)) {
        return catalog[key]!;
      }
    }

    return [
      [
        'Pesquisar "$subject" no YouTube',
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$subject aula')}',
      ],
      [
        'Pesquisar "$subject" revisão',
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$subject revisão')}',
      ],
      [
        'Pesquisar "$subject" exercícios',
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$subject exercícios')}',
      ],
    ];
  }

  Future<void> openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      snack(context, 'Link inválido.');
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      snack(context, 'Não foi possível abrir o YouTube.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = results();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Videoaulas',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: tabs,
          tabs: const [
            Tab(icon: Icon(Icons.play_circle_outline), text: 'Recomendados'),
            Tab(icon: Icon(Icons.video_library_outlined), text: 'Canais'),
            Tab(icon: Icon(Icons.search), text: 'Pesquisar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabs,
        children: [
          _videoList(items, featured: true),
          _channelList(),
          _searchView(items),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B5960), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.ondemand_video_rounded, color: Colors.white, size: 32),
              SizedBox(width: 10),
              Text(
                'EduClass Play',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Videoaulas organizadas por matéria para estudar e planejar aulas.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _videoList(List<List<String>> items, {bool featured = false}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        if (featured) ...[
          _header(),
          const SizedBox(height: 16),
          const Text(
            'Conteúdos em destaque',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
        ],
        if (items.isEmpty)
          const EmptyCard(
            icon: Icons.video_library_outlined,
            title: 'Digite uma matéria',
            text: 'Ex.: Matemática, Física, História ou Biologia.',
          )
        else
          ...items.map(_videoCard),
      ],
    );
  }

  Widget _videoCard(List<String> item) {
    final title = item[0];
    final url = item[1];

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => openLink(url),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 8.7,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF111827), Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'EDUCLASS • YOUTUBE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .7,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE62117),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 14,
                      bottom: 12,
                      child: Text(
                        'ASSISTIR NO YOUTUBE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFFE62117),
                    child: Icon(Icons.smart_display, color: Colors.white),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Conteúdo educacional • toque para abrir',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Abrir no YouTube',
                    onPressed: () => openLink(url),
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelList() {
    final channels = <List<String>>[
      ['Khan Academy Brasil', 'Matemática e ciências', 'https://www.youtube.com/@KhanAcademyBrasil'],
      ['Matemática Rio', 'Matemática e exercícios', 'https://www.youtube.com/@MatematicaRio'],
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        _header(),
        const SizedBox(height: 16),
        const Text(
          'Canais educativos',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...channels.map(
          (channel) => Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(13),
              leading: const CircleAvatar(
                radius: 25,
                backgroundColor: Color(0xFFE62117),
                child: Icon(Icons.play_arrow_rounded, color: Colors.white),
              ),
              title: Text(
                channel[0],
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(channel[1]),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => openLink(channel[2]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchView(List<List<String>> items) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        TextField(
          controller: controller,
          onChanged: (v) => setState(() => subject = v),
          onSubmitted: (v) => setState(() => subject = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => subject = controller.text);
              },
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
            hintText: 'Ex.: Matemática, Física, História...',
          ),
        ),
        const SizedBox(height: 14),
        if (subject.trim().isEmpty)
          const EmptyCard(
            icon: Icons.search_rounded,
            title: 'Pesquise uma matéria',
            text: 'Digite uma matéria para receber cards de videoaulas no estilo de um catálogo de vídeos.',
          )
        else
          ...items.map(_videoCard),
      ],
    );
  }
}

class ScientificArticlesPage extends StatefulWidget {
  const ScientificArticlesPage({super.key});

  @override
  State<ScientificArticlesPage> createState() => _ScientificArticlesPageState();
}

class _ScientificArticlesPageState extends State<ScientificArticlesPage>
    with SingleTickerProviderStateMixin {
  final controller = TextEditingController();
  bool loading = false;
  String query = '';
  List<Map<String, String>> results = [];
  late final TabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    tabs.dispose();
    super.dispose();
  }

  Future searchArticles() async {
    final q = controller.text.trim();
    if (q.isEmpty) return;

    setState(() {
      query = q;
      loading = true;
      results = [];
    });

    try {
      final uri = Uri.parse(
        'https://api.crossref.org/works?query=${Uri.encodeQueryComponent(q)}'
        '&rows=12&select=title,author,published,URL,DOI,container-title',
      );

      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 18));

      if (response.statusCode != 200) throw Exception();

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['message'] as Map<String, dynamic>;
      final rawItems = message['items'];

      if (rawItems is! List) throw Exception();

      results = rawItems.whereType<Map>().map((raw) {
        final item = Map<String, dynamic>.from(raw);
        final titles = item['title'] as List?;
        final authors = item['author'] as List?;
        final year = item['published']?['date-parts']?[0]?[0]?.toString() ?? '';

        final author = authors != null && authors.isNotEmpty
            ? '${authors.first['given'] ?? ''} ${authors.first['family'] ?? ''}'.trim()
            : 'Autor não informado';

        final journal = item['container-title'] is List &&
                (item['container-title'] as List).isNotEmpty
            ? (item['container-title'] as List).first.toString()
            : 'Publicação científica';

        final url = item['URL']?.toString().trim().isNotEmpty == true
            ? item['URL'].toString()
            : item['DOI'] != null
                ? 'https://doi.org/${item['DOI']}'
                : '';

        return <String, String>{
          'title': titles != null && titles.isNotEmpty
              ? titles.first.toString()
              : 'Artigo sem título',
          'author': author.isEmpty ? 'Autor não informado' : author,
          'year': year,
          'journal': journal,
          'url': url,
        };
      }).where((e) => e['url']!.isNotEmpty).toList();
    } catch (_) {
      if (mounted) {
        snack(
          context,
          'Não foi possível consultar os artigos agora. Verifique sua internet.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openArticle(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      snack(context, 'Link do artigo inválido.');
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      snack(context, 'Não foi possível abrir o artigo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Artigos científicos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: tabs,
          tabs: const [
            Tab(icon: Icon(Icons.auto_stories_outlined), text: 'Biblioteca'),
            Tab(icon: Icon(Icons.info_outline), text: 'Como funciona'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabs,
        children: [
          _library(),
          _about(),
        ],
      ),
    );
  }

  Widget _library() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B5960), Color(0xFF145DA0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(23),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.science_rounded, color: Colors.white, size: 31),
              SizedBox(height: 9),
              Text(
                'Biblioteca científica',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Pesquise por tema, disciplina ou palavra-chave e abra o artigo diretamente no site da publicação.',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => searchArticles(),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Ex.: educação inclusiva',
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: loading ? null : searchArticles,
                child: const Icon(Icons.search),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            ),
          ),
        if (!loading && query.isNotEmpty && results.isEmpty)
          const EmptyCard(
            icon: Icons.menu_book_outlined,
            title: 'Nenhum resultado',
            text: 'Tente outra palavra-chave ou uma disciplina diferente.',
          ),
        ...results.map(_articleCard),
      ],
    );
  }

  Widget _articleCard(Map<String, String> article) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 13),
      child: InkWell(
        onTap: () => openArticle(article['url']!),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.article_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title']!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${article['author']} • ${article['year']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      article['journal']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => openArticle(article['url']!),
                          icon: const Icon(Icons.open_in_new, size: 17),
                          label: const Text('Abrir artigo'),
                        ),
                        const SizedBox(width: 7),
                        IconButton(
                          tooltip: 'Copiar link',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: article['url']!),
                            );
                            if (mounted) {
                              snack(context, 'Link do artigo copiado.');
                            }
                          },
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _about() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.public_rounded, color: primary, size: 30),
                SizedBox(height: 10),
                Text(
                  'Pesquisa acadêmica integrada',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'O EduClass consulta metadados públicos do Crossref. Ao tocar em “Abrir artigo”, o aplicativo leva você ao endereço disponibilizado pelo registro do artigo.',
                  style: TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.security_outlined, color: primary),
            title: const Text(
              'Sem PDF incorporado',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'O aplicativo abre o site externo da publicação em vez de copiar o conteúdo do artigo.',
            ),
          ),
        ),
      ],
    );
  }
}

class AllFeaturesPage extends StatelessWidget {
  final ValueChanged<int> onOpen;
  const AllFeaturesPage({super.key, required this.onOpen});

  static const data = [
    [0, 'Início', Icons.home_outlined, 'Resumo da sua rotina'],
    [1, 'Turmas', Icons.groups_outlined, 'Alunos, chamada e relatórios'],
    [2, 'Calendário', Icons.calendar_month_outlined, 'Agenda escolar'],
    [3, 'Comunicação', Icons.forum_outlined, 'Recados e mensagens prontas'],
    [4, 'Planejar aula', Icons.edit_calendar_outlined, 'Planos e conteúdos'],
    [5, 'Relatórios', Icons.bar_chart_outlined, 'Indicadores pedagógicos'],
    [6, 'Banco de ideias', Icons.lightbulb_outline, 'Atividades e metodologias'],
    [7, 'Videoaulas', Icons.ondemand_video_outlined, 'Aulas por matéria'],
    [8, 'Artigos científicos', Icons.science_outlined, 'Pesquisa acadêmica'],
    [9, 'Bem-estar', Icons.favorite_outline, 'Espaço de acolhimento'],
    [10, 'Pendências', Icons.checklist_rounded, 'Tarefas e plano de ação'],
    [11, 'Mais / Perfil', Icons.apps_outlined, 'Configurações e conta'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todas as áreas', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Tudo o que você pode acessar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Escolha uma área para abrir diretamente.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 18),
          ...data.map(
            (item) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                leading: CircleAvatar(
                  backgroundColor: primary.withOpacity(.10),
                  child: Icon(item[2] as IconData, color: primary),
                ),
                title: Text(item[1] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(item[3] as String),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpen(item[0] as int),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  final titleController = TextEditingController();

  Future addMeeting() async {
    if (titleController.text.trim().isEmpty) return;
    setState(() {
      AppData.meetings.add({
        'title': titleController.text.trim(),
        'date': formatDate(DateTime.now()),
      });
      titleController.clear();
    });
    await AppData.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reuniões Pedagógicas')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: titleController,
                  decoration: const InputDecoration(hintText: 'Assunto da reunião...'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: addMeeting, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 18),
          ...AppData.meetings.map((m) => Card(
            child: ListTile(
              leading: const Icon(Icons.groups_outlined, color: primary),
              title: Text(m['title'] ?? ''),
              subtitle: Text('Data: ${m['date']}'),
            ),
          )),
        ],
      ),
    );
  }
}

class GoogleAccountPage extends StatefulWidget {
  const GoogleAccountPage({super.key});

  @override
  State<GoogleAccountPage> createState() => _GoogleAccountPageState();
}

class _GoogleAccountPageState extends State<GoogleAccountPage> {
  bool loading = false;

  Future<void> conectar() async {
    if (loading) return;
    setState(() => loading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final account = await googleSignIn.signIn();

      if (account == null) {
        throw Exception('Login Google cancelado.');
      }
      AppData.googleName = account.displayName ?? '';
      AppData.googleEmail = account.email;
      AppData.name = AppData.googleName.isEmpty
          ? account.email.split('@').first
          : AppData.googleName;
      AppData.email = account.email;
      AppData.accountCreated = true;
      await AppData.save();

      if (mounted) {
        setState(() {});
        snack(context, 'Conta Google conectada.');
      }
    } catch (_) {
      if (mounted) {
        snack(context, 'Não foi possível conectar. Verifique a configuração do Google Sign-In.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> desconectar() async {
    try {
      await GoogleSignIn().disconnect();
    } catch (_) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }

    AppData.googleName = '';
    AppData.googleEmail = '';
    await AppData.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final connected = AppData.googleEmail.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Conta Google')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: primary.withOpacity(.10),
                          child: const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              color: primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                connected
                                    ? (AppData.googleName.isEmpty
                                        ? 'Conta Google conectada'
                                        : AppData.googleName)
                                    : 'Nenhuma conta conectada',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                connected
                                    ? AppData.googleEmail
                                    : 'Conecte sua conta Google ao EduClass',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: loading ? null : (connected ? desconectar : conectar),
                    icon: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(connected ? Icons.logout : Icons.login),
                    label: Text(
                      loading
                          ? 'Conectando...'
                          : (connected
                              ? 'Desconectar conta Google'
                              : 'Conectar com Google'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
