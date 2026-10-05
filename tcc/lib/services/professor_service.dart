import '../database/db.dart';

/// Serviço responsável pelos cadastros locais de professores/usuários.
class ProfessorService {
  static Future<int> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required String escola,
    required String municipio,
    required String estado,
    required List<String> materias,
  }) {
    return BancoDados.inserirUsuario(
      nome: nome,
      email: email,
      senha: senha,
      escola: escola,
      municipio: municipio,
      estado: estado,
      materias: materias,
    );
  }

  static Future<Map<String, dynamic>?> buscarPorEmail(String email) {
    return BancoDados.buscarUsuario(email);
  }

  static Future<List<Map<String, dynamic>>> listar() {
    return BancoDados.listarUsuarios();
  }
}
