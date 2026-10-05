const sqlite3 = require('sqlite3').verbose();

const db = new sqlite3.Database('./educlass.db', (err) => {
  if (err) {
    console.error('❌ Erro ao abrir o banco:', err.message);
    return;
  }

  console.log('✅ Banco SQLite aberto com sucesso!');
});

db.all(
  "SELECT name FROM sqlite_master WHERE type='table'",
  (err, rows) => {
    if (err) {
      console.error('❌ Erro ao consultar tabelas:', err.message);
    } else {
      console.log('\n📋 Tabelas encontradas:');
      console.table(rows);
    }

    db.close((err) => {
      if (err) {
        console.error('❌ Erro ao fechar banco:', err.message);
      } else {
        console.log('\n✅ Teste concluído!');
      }
    });
  }
);