def get_dataBase()
    db = SQLite3::Database.new("db/Database.db")
    db.results_as_hash = true
    return db
end

def update_user_info()
    db = get_dataBase()
    session[:user] = db.execute("SELECT * FROM Users WHERE id = ?", session[:user]["id"]).first
end

def delete_post(post_id)
    db = get_dataBase()
    db.execute("DELETE FROM Posts WHERE id = #{post_id}")
end

def update_text(post_id, new_text)
    db = get_dataBase()
    db.execute("UPDATE Posts SET text = ? WHERE id = #{post_id}", new_text)
end

def get_all_posts()
    db = get_dataBase()
    return db.execute("SELECT * FROM Posts")
end

def post_boulder(type, boulder_id)
    db = get_dataBase()
    boulder_name = db.execute("SELECT name FROM Boulders WHERE id = #{boulder_id}").first["name"]
    p boulder_name
    text = "#{session[:user]["username"]} has updated the status of #{boulder_name}: #{type}"
    p text
    db.execute("INSERT INTO Posts (user_id, boulder_id, date_posted, time_posted, text) VALUES (?,?,?,?,?)", session[:user]["id"], boulder_id, Time.now.strftime("%d/%m/%Y"), Time.now.strftime("%H:%M"), text)
    # db.execute("INSERT INTO Posts (user_id, boulder_id, date_posted, time_posted, text) VALUES (#{session[:users]["id"]}, #{boulder_id}, '#{Time.now.strftime("%d/%m/%Y")}', '#{Time.now.strftime("%H:%M")}, #{text})")
end

def get_relevent_posts()
    # follows_id = db.execute("SELECT user_id FROM Follower_rel WHERE followed_by_id = #{session[:user]["id"]}")
    db = get_dataBase()
    p db.execute("SELECT * FROM Posts INNER JOIN Follower_rel ON Posts.user_id = Follower_rel.user_id WHERE Follower_rel.followed_by_id = ? ORDER BY Posts.date_posted, Posts.time_posted DESC", session[:user]["id"])
    return db.execute("SELECT * FROM Posts INNER JOIN Follower_rel ON Posts.user_id = Follower_rel.user_id WHERE Follower_rel.followed_by_id = ? ORDER BY Posts.date_posted, Posts.time_posted DESC", session[:user]["id"])
end

def get_comments(post_id)
    db = get_dataBase()
    return db.execute("SELECT p.* FROM Posts AS p, Posts AS p2 WHERE p.posted_on = p2.id AND p2.id = #{post_id} ORDER BY likes DESC")
end

def post_comment(text, post_id)
    db = get_dataBase()
    db.execute("INSERT INTO Posts (user_id, posted_on, date_posted, time_posted, text) VALUES (?,?,?,?,?)", session[:user]["id"], post_id, Time.now.strftime("%d/%m/%Y"), Time.now.strftime("%H:%M"), text)
end

def like_post(post_id)
    db = get_dataBase()
    db.execute("INSERT INTO Like_rel (post_id, user_id) VALUES (#{post_id}, #{session[:user]["id"]})")
    db.execute("UPDATE Posts SET likes = likes + 1 WHERE id = #{post_id}")
end

def unlike_post(post_id)
    db = get_dataBase()
    db.execute("DELETE FROM Like_rel WHERE post_id =  #{post_id}")
    db.execute("UPDATE Posts SET likes = likes - 1 WHERE id = #{post_id}")
end

def get_post_chain(post_id)
    db = get_dataBase()
    relevant_post_id = post_id
    continue = true
    chain_array = db.execute("SELECT * FROM Posts WHERE id = #{post_id}")
    # chain_array = []
    while continue
        next_post = db.execute("SELECT p.* FROM Posts as p, Posts AS p2 WHERE p.id = p2.posted_on AND p2.id = #{relevant_post_id}").first
        # p next_post
        if next_post == nil
            continue = false
        else
            chain_array << next_post
            relevant_post_id = next_post["id"]
            # p relevant_post_id
        end
        # p "the chain array is so far", chain_array
    end
    return chain_array
end

def create_post(text)
    db = get_dataBase()
    # p "INSERT INTO Posts (user_id, text, posted_on, date_posted, time_posted) VALUES (#{session[:user]["id"]}, ?, '/', #{Time.now.strftime("%d/%m/%Y")}, #{Time.now.strftime("%H:%M")})"
    db.execute("INSERT INTO Posts (user_id, text, date_posted, time_posted) VALUES (#{session[:user]["id"]}, ?, '#{Time.now.strftime("%d/%m/%Y")}', '#{Time.now.strftime("%H:%M")}')", text)
end

def untick_boulder(boulder_id)
    db = get_dataBase()
    db.execute("DELETE FROM Boulder_User_rel WHERE boulder_id = ?", boulder_id)
end

def rank(inp_array, term)
    array = inp_array.dup
    sorted_arr = []
    array.each do |item|
        # p item
        score = 0
        i = 0
        # p item[i..i + term.length-1]
        while i + term.length < item.length && item[i..i + term.length-1].downcase != term
            i += 1
            # p item[i..i + term.length-1]
        end
        # kollar hur stor del av item som är termen vi söker efter och vart i item som termen ligger för att ranka hur bra de olika itemsen matchar termen
        if item.length > 1
            score = (term.length.to_f / item.length.to_f + (item.length - 1 - i.to_f) / (item.length.to_f - 1))/2
        else
            score = 1
        end
        # p item, score 
        if sorted_arr.length != 0 
            i = 0
            # p sorted_arr[i]
            while i < sorted_arr.length && sorted_arr[i][1] >= score
                # p sorted_arr[i]
                i += 1
            end
            if i != 0
                sorted_arr = sorted_arr[0..i-1] + [[item, score]] + sorted_arr[i..sorted_arr.length]
            else
                sorted_arr = [[item, score]] + sorted_arr
            end
        else
            sorted_arr << [item, score]
        end
        # p sorted_arr
    end
    final_ranking = []
    sorted_arr.each do |arr|
        final_ranking << arr[0]
    end
    # p final_ranking
    return final_ranking
end

def tick_boulder(boulder_id, type)
    # p type, "(#{boulder_id}, #{session[:user]["id"]}, #{type})"
    db = get_dataBase()
    db.execute("INSERT INTO Boulder_User_rel (boulder_id, user_id, type_of_rel) VALUES (#{boulder_id}, #{session[:user]["id"]}, '#{type}')")
end

def clear_table(tablename)
    db = get_dataBase()
    db.execute("DELETE FROM #{tablename}")
end

def log_in(username, password)
    db = get_dataBase()
    password_from_db = db.execute("SELECT password_digest FROM Users WHERE username = ?", username).first
    # p password_from_db
    if password_from_db == nil
        session[:log_in_error] = "Username does not exist"
    elsif BCrypt::Password.new(password_from_db["password_digest"]) == password
        session[:user] = db.execute("SELECT * FROM Users WHERE username = ?", username).first
    else
        session[:log_in_error] = "Password is incorrect"
    end
end

def get_users()
    db = get_dataBase()
    return db.execute("SELECT username FROM Users")
end

def create_user(new_username, password_digest)
    db.execute("INSERT INTO Users (username, password_digest) VALUES (?,?)",new_username, password_digest)
end

def log_in_username(username)
    session[:user] = db.execute("SELECT * FROM Users WHERE username = ?", username).first
end

def find_search_results(search_input)
    db = get_dataBase()
    # results = {:Users => [], :Problems => []}
    results = {"Users" => [], "Boulders" => []}
    result_data_array = {"Users" => [], "Boulders" => []}
    [{:table_name => "Users", :variables => ["username"]}, {:table_name => "Boulders", :variables => ["name", "location"]}].each do |table|
        query = ""
        table[:variables].each_with_index do |variable, i|
            if i > 0
                query += " OR #{variable} LIKE '%#{search_input}%'"
            else
                query += "#{variable} LIKE '%#{search_input}%'"
            end
        end
        # p "SELECT * FROM #{table[:table_name]} WHERE #{query}"
        content = db.execute("SELECT * FROM #{table[:table_name]} WHERE #{query}")
        # p content
        unsorted_result = []
        content.each do |cont|
            arr = []
            table[:variables].each do |variable|
                arr << cont[variable]
            end
            # variable_to_show = rank(arr, search_input).first
            unsorted_result << {"variable" => rank(arr, search_input).first, "id" => cont["id"]}
        end
        # p unsorted_result
        results[table[:table_name]] = rank_with_id(unsorted_result, search_input)
        results[table[:table_name]].each do |result|
            data = db.execute("SELECT * FROM #{table[:table_name]} WHERE id LIKE ?", result["id"]).first
            # p "boulder datan är: #{data}, och arrayen är: #{result_data_array}"
            if data != nil
                result_data_array[table[:table_name]] << data
            end
        end
    end
    return result_data_array
end

def update_bio(new_bio)
    db = get_dataBase()
    db.execute("UPDATE Users SET bio = ? WHERE id = #{session[:user]["id"]}", new_bio)
end 

def follow(user_to_follow_id)
    db = get_dataBase()
    db.execute("INSERT INTO Follower_rel VALUES (#{user_to_follow_id}, #{session[:user]["id"]})")
    db.execute("UPDATE Users SET followers = #{db.execute("SELECT followers FROM Users  where id = ?", user_to_follow_id).first["followers"] + 1} WHERE id = ?", user_to_follow_id)
end

def unfollow(user_to_unfollow_id)
    db = get_dataBase()
    db.execute("DELETE FROM Follower_rel WHERE (user_id, followed_by_id) = (?,?)", user_to_unfollow_id, session[:user]["id"])
    db.execute("UPDATE Users SET followers = #{db.execute("SELECT followers FROM Users  where id = ?", user_to_unfollow_id).first["followers"] - 1} WHERE id = ?", user_to_unfollow_id)
end

def get_boulder_from_name(boulder_name)
    db = get_dataBase()
    return db.execute("SELECT * FROM Boulders WHERE name = ?", boulder_name).first
end

def create_boulder(boudler_name, grade, location, description, path)
    db.execute("INSERT INTO Boulders (name, location, set_by, description, grade, pic_path) VALUES (?,?,?,?,?,?)", boulder_name, location, session[:user]["username"], description, grade, path)
end

helpers do
    def get_where(requested_cont, table, condition, var)
        db = get_dataBase()
        # p "SELEaewfCT #{requested_cont} FROM #{table} WHERE #{condition} = #{var}"
        return db.execute("SELECT #{requested_cont} FROM #{table} WHERE #{condition} = ?",var)
    end

    def ticked?(boulder)
        if session[:user] != nil
            db = get_dataBase()
            # p db.execute("SELECT * FROM Boulder_User_rel INNER JOIN Users ON Boulder_User_rel.user_id = Users.id WHERE Users.id = #{session[:user]["id"]} AND Boulder_User_rel.boulder_id = #{boulder["id"]}")
            if db.execute("SELECT * FROM Boulder_User_rel INNER JOIN Users ON Boulder_User_rel.user_id = Users.id WHERE Users.id = #{session[:user]["id"]} AND Boulder_User_rel.boulder_id = #{boulder["id"]}").length > 0
                return true
            end
        end
        return false
    end

    def tick_type(boulder, user_id)
        db = get_dataBase
        tick_type = db.execute("SELECT type_of_rel FROM Boulder_User_rel WHERE boulder_id = #{boulder["id"]} AND user_id = #{user_id}").first
        return tick_type["type_of_rel"]
    end

    def follows?(user_id, follower_id)
        db = get_dataBase()
        check = db.execute("SELECT * FROM Follower_rel WHERE (user_id, followed_by_id) = (?,?)", user_id, follower_id)
        # p check
        if check != []
            return true
        else
            return false
        end
    end

    def get_boulders()
        db = get_dataBase()
        boulders = db.execute("SELECT * FROM Boulders")
    end

    def get_search_options()
        db = get_dataBase()
        search_options = {"combined" => []}
        # p db.execute("SELECT name FROM Users")
        search_options["Users"] = db.execute("SELECT username FROM Users")
        search_options["Problems"] = db.execute("SELECT name, location from Boulders")
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

    def get_boulders_sent(user_id)
        # p "detta händer"
        db = get_dataBase()
        # # p db.execute("SELECT * FROM Problems WHERE id LIKE Problem_User_rel.problem_id AND Problem_User_rel.user_id = ?", user_id)
        # boulder_data = []
        # # db.execute("SELECT * FROM Boulder_User_rel WHERE user_id = #{user_id}").each do |boulder_id|
        # #     boulder_data << db.execute("SELECT * FROM Boulders WHERE id = #{boulder_id}").first
        # # end
        return db.execute("SELECT * FROM Boulders INNER JOIN Boulder_User_rel On Boulders.id = Boulder_User_rel.boulder_id WHERE Boulder_User_rel.user_id = #{user_id}")
    end

    def get_top_results(search_input)
        db = get_dataBase()
        # p "printar alla boulders"
        # p db.execute("SELECT * Boulders")
    end

    def get_posts_from_user(user_id)
        db = get_dataBase()
        return db.execute("SELECT * FROM Posts WHERE user_id = ? ORDER BY Posts.date_posted, Posts.time_posted DESC ", user_id)
    end

    def get_user(user_id)
        db = get_dataBase()
        return db.execute("SELECT * FROM Users WHERE id = ?", user_id).first
    end 

    def get_top_5_follows(user_id)
        db = get_dataBase()
        ordered_follows = db.execute("SELECT * FROM Follower_rel AS Fr INNER JOIN Users ON Users.id = Fr.user_id WHERE followed_by_id = #{user_id} ORDER BY Users.followers DESC")
        if ordered_follows.length < 5
            return ordered_follows
        else
            # p ordered_follows[0..5]
            return ordered_follows[0..4]
        end
    end
    
    def is_liked(post_id)
        # p post_id
        db = get_dataBase()
        # p "SELECT * FROM Like_rel WHERE post_id = #{post_id} AND user_id = #{session[:user]["id"]}"
        # p db.execute("SELECT * FROM Like_rel WHERE post_id = #{post_id} AND user_id = #{session[:user]["id"]}").length != 0
        return db.execute("SELECT * FROM Like_rel WHERE post_id = #{post_id} AND user_id = #{session[:user]["id"]}").length != 0
    end

    def number_of_likes(post_id)
        db = get_dataBase()
        return db.execute("SELECT likes FROM Posts WHERE id = #{post_id}").first["likes"]
    end

    def get_poster(post_id)
        db = get_dataBase()
        return db.execute("SELECT * FROM Users INNER JOIN Posts ON Posts.user_id = Users.id WHERE Posts.id = #{post_id}").first
    end
end 

