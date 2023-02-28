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

helpers do
    def follows?(user_id, follower_id)
        db = get_dataBase()
        check = db.execute("SELECt * FROM Follower_rel WHERE (user_id, followed_by_id) = (?,?)", user_id, follower_id)
        p check
        if check != []
            return true
        else
            return false
        end
    end
end

def clear_table(tablename)
    db = get_dataBase()
    db.execute("DELETE FROM #{tablename}")
end