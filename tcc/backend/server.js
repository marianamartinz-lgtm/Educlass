const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');

const pool = require('./database-postgres');

const app = express();


// ============================================================
// CONFIGURAÇÕES
// ============================================================

app.use(cors());
app.use(express.json());


// ============================================================
// TESTE DA API
// ============================================================

app.get('/', (req, res) => {
  res.json({
    status: 'API funcionando 🚀',
    projeto: 'EduClass',
  });
});


// ============================================================
// ALUNOS
// ============================================================

// Buscar alunos
app.get('/alunos', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT *
      FROM alunos
      ORDER BY id ASC
    `);

    res.json(result.rows);

  } catch (err) {
    console.error('Erro ao buscar alunos:', err.message);

    res.status(500).json({
      erro: err.message,
    });
  }
});


// Criar aluno
app.post('/alunos', async (req, res) => {

  const {
    nome,
    data_nascimento,
    turma_id,
  } = req.body;


  if (!nome || nome.trim() === '') {

    return res.status(400).json({
      erro: 'Nome do aluno é obrigatório.',
    });
  }


  try {

    const result = await pool.query(
      `
      INSERT INTO alunos
        (
          nome,
          data_nascimento,
          turma_id
        )
      VALUES
        ($1, $2, $3)

      RETURNING *
      `,
      [
        nome.trim(),
        data_nascimento || null,
        turma_id || null,
      ]
    );


    res.status(201).json({

      mensagem: 'Aluno criado com sucesso!',

      aluno: result.rows[0],

    });


  } catch (err) {

    console.error(
      'Erro ao criar aluno:',
      err.message
    );


    res.status(500).json({
      erro: err.message,
    });
  }
});


// ============================================================
// PROFESSORES - LISTAR
// ============================================================

app.get('/professores', async (req, res) => {

  try {

    const result = await pool.query(`
      SELECT

        p.id,
        p.nome,
        p.email,
        p.criado_em,

        e.id AS estado_id,
        e.codigo_ibge AS estado_codigo_ibge,
        e.sigla AS estado_sigla,
        e.nome AS estado_nome,

        m.id AS municipio_id,
        m.codigo_ibge AS municipio_codigo_ibge,
        m.nome AS municipio_nome,

        es.id AS escola_id,
        es.nome AS escola_nome,
        es.codigo_inep AS escola_codigo_inep

      FROM professores p

      LEFT JOIN estados e
        ON e.id = p.estado_id

      LEFT JOIN municipios m
        ON m.id = p.municipio_id

      LEFT JOIN escolas es
        ON es.id = p.escola_id

      ORDER BY p.id ASC
    `);


    res.json(result.rows);


  } catch (err) {

    console.error(
      'Erro ao buscar professores:',
      err.message
    );


    res.status(500).json({
      erro: err.message,
    });
  }
});


// ============================================================
// PROFESSOR POR ID
// ============================================================

app.get('/professores/:id', async (req, res) => {

  const { id } = req.params;


  try {

    const professorResult = await pool.query(
      `
      SELECT

        p.id,
        p.nome,
        p.email,
        p.criado_em,

        e.id AS estado_id,
        e.codigo_ibge AS estado_codigo_ibge,
        e.sigla AS estado_sigla,
        e.nome AS estado_nome,

        m.id AS municipio_id,
        m.codigo_ibge AS municipio_codigo_ibge,
        m.nome AS municipio_nome,

        es.id AS escola_id,
        es.nome AS escola_nome,
        es.codigo_inep AS escola_codigo_inep

      FROM professores p

      LEFT JOIN estados e
        ON e.id = p.estado_id

      LEFT JOIN municipios m
        ON m.id = p.municipio_id

      LEFT JOIN escolas es
        ON es.id = p.escola_id

      WHERE p.id = $1
      `,
      [id]
    );


    if (professorResult.rows.length === 0) {

      return res.status(404).json({
        erro: 'Professor não encontrado.',
      });
    }


    const professor =
      professorResult.rows[0];


    const materiasResult =
      await pool.query(
        `
        SELECT

          m.id,
          m.nome

        FROM materias m

        INNER JOIN professor_materias pm
          ON pm.materia_id = m.id

        WHERE pm.professor_id = $1

        ORDER BY m.nome ASC
        `,
        [id]
      );


    professor.materias =
      materiasResult.rows;


    res.json(professor);


  } catch (err) {

    console.error(
      'Erro ao buscar professor:',
      err.message
    );


    res.status(500).json({
      erro: err.message,
    });
  }
});


// ============================================================
// CADASTRAR PROFESSOR
// ============================================================

app.post('/professores', async (req, res) => {

  const {
    nome,
    email,
    senha,

    estadoId,
    estadoNome,
    estadoSigla,

    municipioId,
    municipioNome,

    escola,

    materias,
  } = req.body;


  // ==========================================================
  // VALIDAÇÃO
  // ==========================================================

  if (!nome || nome.trim() === '') {

    return res.status(400).json({
      erro: 'Nome é obrigatório.',
    });
  }


  if (!email || email.trim() === '') {

    return res.status(400).json({
      erro: 'E-mail é obrigatório.',
    });
  }


  if (!senha || senha.length < 6) {

    return res.status(400).json({
      erro: 'A senha precisa ter pelo menos 6 caracteres.',
    });
  }


  if (!estadoId || !estadoNome) {

    return res.status(400).json({
      erro: 'Estado é obrigatório.',
    });
  }


  if (!municipioId || !municipioNome) {

    return res.status(400).json({
      erro: 'Município é obrigatório.',
    });
  }


  if (!escola || escola.trim() === '') {

    return res.status(400).json({
      erro: 'Escola é obrigatória.',
    });
  }


  if (!Array.isArray(materias) || materias.length === 0) {

    return res.status(400).json({
      erro: 'Selecione pelo menos uma matéria.',
    });
  }


  const emailNormalizado =
    email.trim().toLowerCase();


  // ==========================================================
  // CONEXÃO
  // ==========================================================

  const client = await pool.connect();


  try {

    // Começar transação
    await client.query('BEGIN');


    // ========================================================
    // 1. VERIFICAR E-MAIL
    // ========================================================

    const emailExiste =
      await client.query(
        `
        SELECT id
        FROM professores
        WHERE LOWER(email) = LOWER($1)
        LIMIT 1
        `,
        [emailNormalizado]
      );


    if (emailExiste.rows.length > 0) {

      await client.query('ROLLBACK');


      return res.status(409).json({
        erro: 'Este e-mail já está cadastrado.',
      });
    }


    // ========================================================
    // 2. ESTADO
    // ========================================================

    const estadoResult =
      await client.query(
        `
        INSERT INTO estados
          (
            codigo_ibge,
            sigla,
            nome
          )
        VALUES
          ($1, $2, $3)

        ON CONFLICT (codigo_ibge)

        DO UPDATE SET

          sigla = EXCLUDED.sigla,
          nome = EXCLUDED.nome

        RETURNING id
        `,
        [
          String(estadoId),
          estadoSigla || '',
          estadoNome.trim(),
        ]
      );


    const estadoDbId =
      estadoResult.rows[0].id;


    // ========================================================
    // 3. MUNICÍPIO
    // ========================================================

    const municipioResult =
      await client.query(
        `
        INSERT INTO municipios
          (
            codigo_ibge,
            nome,
            estado_id
          )
        VALUES
          ($1, $2, $3)

        ON CONFLICT (codigo_ibge)

        DO UPDATE SET

          nome = EXCLUDED.nome,
          estado_id = EXCLUDED.estado_id

        RETURNING id
        `,
        [
          String(municipioId),
          municipioNome.trim(),
          estadoDbId,
        ]
      );


    const municipioDbId =
      municipioResult.rows[0].id;


    // ========================================================
    // 4. ESCOLA
    // ========================================================

    const escolaExiste =
      await client.query(
        `
        SELECT id

        FROM escolas

        WHERE
          LOWER(nome) = LOWER($1)
          AND municipio_id = $2

        LIMIT 1
        `,
        [
          escola.trim(),
          municipioDbId,
        ]
      );


    let escolaDbId;


    if (escolaExiste.rows.length > 0) {

      escolaDbId =
        escolaExiste.rows[0].id;

    } else {

      const escolaResult =
        await client.query(
          `
          INSERT INTO escolas
            (
              nome,
              municipio_id,
              estado_id
            )
          VALUES
            ($1, $2, $3)

          RETURNING id
          `,
          [
            escola.trim(),
            municipioDbId,
            estadoDbId,
          ]
        );


      escolaDbId =
        escolaResult.rows[0].id;
    }


    // ========================================================
    // 5. CRIAR HASH DA SENHA
    // ========================================================

    const senhaHash =
      await bcrypt.hash(senha, 10);


    // ========================================================
    // 6. CRIAR PROFESSOR
    // ========================================================

    const professorResult =
      await client.query(
        `
        INSERT INTO professores
          (
            nome,
            email,
            senha_hash,
            estado_id,
            municipio_id,
            escola_id
          )

        VALUES
          ($1, $2, $3, $4, $5, $6)

        RETURNING
          id,
          nome,
          email,
          estado_id,
          municipio_id,
          escola_id,
          criado_em
        `,
        [
          nome.trim(),
          emailNormalizado,
          senhaHash,
          estadoDbId,
          municipioDbId,
          escolaDbId,
        ]
      );


    const professor =
      professorResult.rows[0];


    // ========================================================
    // 7. MATÉRIAS
    // ========================================================

    const materiasSalvas = [];


    for (const materia of materias) {

      if (
        typeof materia !== 'string' ||
        materia.trim() === ''
      ) {
        continue;
      }


      const materiaNome =
        materia.trim();


      // Criar matéria caso não exista
      const materiaResult =
        await client.query(
          `
          INSERT INTO materias
            (
              nome
            )

          VALUES
            ($1)

          ON CONFLICT (nome)

          DO UPDATE SET
            nome = EXCLUDED.nome

          RETURNING id, nome
          `,
          [materiaNome]
        );


      const materiaDb =
        materiaResult.rows[0];


      materiasSalvas.push(
        materiaDb
      );


      // ======================================================
      // 8. RELACIONAR PROFESSOR + MATÉRIA
      // ======================================================

      await client.query(
        `
        INSERT INTO professor_materias
          (
            professor_id,
            materia_id
          )

        VALUES
          ($1, $2)

        ON CONFLICT
          (
            professor_id,
            materia_id
          )

        DO NOTHING
        `,
        [
          professor.id,
          materiaDb.id,
        ]
      );
    }


    // ========================================================
    // 9. CONFIRMAR TUDO
    // ========================================================

    await client.query('COMMIT');


    // ========================================================
    // 10. RESPOSTA
    // ========================================================

    res.status(201).json({

      mensagem:
        'Professor cadastrado com sucesso!',

      professor: {

        id: professor.id,

        nome: professor.nome,

        email: professor.email,

        estado: {
          id: estadoDbId,
          codigo_ibge: String(estadoId),
          sigla: estadoSigla || '',
          nome: estadoNome,
        },

        municipio: {
          id: municipioDbId,
          codigo_ibge: String(municipioId),
          nome: municipioNome,
        },

        escola: {
          id: escolaDbId,
          nome: escola.trim(),
        },

        materias:
          materiasSalvas,
      },
    });


  } catch (err) {

    // ========================================================
    // DESFAZER TUDO SE DER ERRO
    // ========================================================

    await client.query('ROLLBACK');


    console.error(
      '======================================'
    );

    console.error(
      '❌ ERRO AO CADASTRAR PROFESSOR'
    );

    console.error(
      err
    );

    console.error(
      '======================================'
    );


    res.status(500).json({
      erro: err.message,
    });


  } finally {

    // Liberar conexão
    client.release();
  }
});


// ============================================================
// LOGIN
// ============================================================

app.post('/login', async (req, res) => {

  const {
    email,
    senha,
  } = req.body;


  if (!email || !senha) {

    return res.status(400).json({
      erro: 'E-mail e senha são obrigatórios.',
    });
  }


  try {

    const result =
      await pool.query(
        `
        SELECT

          p.id,
          p.nome,
          p.email,
          p.senha_hash,

          e.nome AS estado_nome,
          e.sigla AS estado_sigla,

          m.nome AS municipio_nome,

          es.nome AS escola_nome

        FROM professores p

        LEFT JOIN estados e
          ON e.id = p.estado_id

        LEFT JOIN municipios m
          ON m.id = p.municipio_id

        LEFT JOIN escolas es
          ON es.id = p.escola_id

        WHERE LOWER(p.email) = LOWER($1)

        LIMIT 1
        `,
        [
          email.trim(),
        ]
      );


    if (result.rows.length === 0) {

      return res.status(401).json({
        erro: 'E-mail ou senha incorretos.',
      });
    }


    const professor =
      result.rows[0];


    // Comparar senha digitada com o hash
    const senhaCorreta =
      await bcrypt.compare(
        senha,
        professor.senha_hash
      );


    if (!senhaCorreta) {

      return res.status(401).json({
        erro: 'E-mail ou senha incorretos.',
      });
    }


    // Nunca enviar senha_hash para o Flutter
    delete professor.senha_hash;


    res.json({

      mensagem: 'Login realizado com sucesso!',

      professor,

    });


  } catch (err) {

    console.error(
      'Erro no login:',
      err.message
    );


    res.status(500).json({
      erro: err.message,
    });
  }
});


// ============================================================
// INICIAR SERVIDOR
// ============================================================

app.listen(3000, () => {

  console.log(
    '======================================'
  );

  console.log(
    '🚀 EDUCLASS API RODANDO'
  );

  console.log(
    '🌐 http://localhost:3000'
  );

  console.log(
    '======================================'
  );
});