def get_dataBase()
    db = SQLite3::Database.new("db/Database.db")
    db.results_as_hash = true
    return db
end

helpers do
    def get_where(requested_cont, table, condition, var)
        db = get_dataBase()
        # p "SELEaewfCT #{requested_cont} FROM #{table} WHERE #{condition} = #{var}"
        return db.execute("SELECT #{requested_cont} FROM #{table} WHERE #{condition} = ?",var)
    end
end