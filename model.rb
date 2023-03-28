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
        check = db.execute("SELECT * FROM Follower_rel WHERE (user_id, followed_by_id) = (?,?)", user_id, follower_id)
        p check
        if check != []
            return true
        else
            return false
        end
    end
end

helpers do
    def get_boulders()
        db = get_dataBase()
        boulders = db.execute("SELECT * FROM Problems")
    end
end

helpers do
    def get_search_options()
        db = get_dataBase()
        search_options = {"combined" => []}
        # p db.execute("SELECT name FROM Users")
        search_options["Users"] = db.execute("SELECT username FROM Users")
        search_options["Problems"] = db.execute("SELECT name, location from Problems")
        # p search_options
        {}
        [{:table_name => "Users", :variables => ["username"]}, {:table_name => "Problems", :variables => ["name", "location"]}].each do |table|
            table[:variables].each do |variable|
                search_options[table[:table_name]].each do |temp|
                    # p temp
                    # p search_options[table[:table_name]][variable]
                    search_options["combined"] << temp[variable]
                end
            end
        end
        # p search_options["combined"]
        return search_options["combined"]
    end
end

def clear_table(tablename)
    db = get_dataBase()
    db.execute("DELETE FROM #{tablename}")
end

helpers do
    def get_boulders_sent(user_id)
        p "detta händer"
        db = get_dataBase()
        # p db.execute("SELECT * FROM Problems WHERE id LIKE Problem_User_rel.problem_id AND Problem_User_rel.user_id = ?", user_id)
        problem_data = []
        db.execute("SELECT problem_id FROM Problem_User_rel WHERE user_id = #{user_id}").each do |problem_id|
            problem data << db.execute("SELECT * FROM Problems WHERE id = #{problem_id}").first
        end
        # p db.execute("SELECT * FROM Problem_User_rel WHERE user_id = #{user_id} AS table, SELECT * from Problems WHERE Problems.id = table.problem_id")
        p problem_data
        return problem_data
    end
end