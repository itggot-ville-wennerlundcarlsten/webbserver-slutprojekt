def connect()
    db = SQLite3::Database.new("./database/db.sqlite")
    return db
end