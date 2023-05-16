# A module to handle interactions with a database
# 
module Model

    # Creates and returns a SQLite3::Database object 
    # 
    # @returns [SQLite3::Database] returns a SQLite3::Database object with results_as_hash = true as defult
    def get_dataBase()
        db = SQLite3::Database.new("db/Database.db")
        db.results_as_hash = true
        # db.execute("PRAGMA foreign_keys = ON")
        return db
    end

    # Updates the user info stored in session to match the Users table
    # 
    def update_user_info()
        db = get_dataBase()
        session[:user] = db.execute("SELECT * FROM Users WHERE id = ?", session[:user]["id"]).first
        # db.execute("UPDATE Users SET profile_pic = ? WHERE id = #{session[:user]["id"]}", path)
    end

    # Deletes a post from the Posts table
    # 
    # @params [String] post_id, id of the post to delete
    def delete_post(post_id)
        db = get_dataBase()
        db.execute("PRAGMA foreign_keys = ON")
        db.execute("DELETE FROM Posts WHERE id = #{post_id}")
    end

    # Updates the text of a post in the Posts table
    # 
    # @param [String] post_id, id of the post to update
    # @param [String] new_text, the new text of the post
    def update_text(post_id, new_text)
        db = get_dataBase()
        # p new_text
        db.execute("UPDATE Posts SET text = ? WHERE id = #{post_id}", new_text)
    end

    # Gets all posts in the Posts table
    # 
    # @returns [Array] returns an array of all posts in the Posts table
    def get_all_posts()
        db = get_dataBase()
        return db.execute("SELECT * FROM Posts")
    end

    # Posts the updated status of a boulder in regards to the logged in user
    # 
    # @param [String] type, the new status type of the boulder in regards to the user
    # @param [String] boulder_id, id of the boulder
    def post_boulder(type, boulder_id)
        db = get_dataBase()
        boulder_name = db.execute("SELECT name FROM Boulders WHERE id = #{boulder_id}").first["name"]
        # p boulder_name
        text = "#{session[:user]["username"]} has updated the status of #{boulder_name}: #{type}"
        # p text
        db.execute("INSERT INTO Posts (user_id, boulder_id, date_posted, time_posted, text) VALUES (?,?,?,?,?)", session[:user]["id"], boulder_id, Time.now.strftime("%d/%m/%Y"), Time.now.strftime("%H:%M"), text)
        # db.execute("INSERT INTO Posts (user_id, boulder_id, date_posted, time_posted, text) VALUES (#{session[:users]["id"]}, #{boulder_id}, '#{Time.now.strftime("%d/%m/%Y")}', '#{Time.now.strftime("%H:%M")}, #{text})")
    end

    # Gets all posts from users the logged in user is following and orders them by the date and time posted
    # 
    # @returns [Array] returns an array of all posts by users the logged in user is following in descending order based on the date and time of creation
    def get_relevent_posts()
        # follows_id = db.execute("SELECT user_id FROM Follower_rel WHERE followed_by_id = #{session[:user]["id"]}")
        db = get_dataBase()
        # p db.execute("SELECT * FROM Posts INNER JOIN Follower_rel ON Posts.user_id = Follower_rel.user_id WHERE Follower_rel.followed_by_id = ? ORDER BY Posts.date_posted, Posts.time_posted DESC", session[:user]["id"])
        return db.execute("SELECT * FROM Posts INNER JOIN Follower_rel ON Posts.user_id = Follower_rel.user_id WHERE Follower_rel.followed_by_id = ? ORDER BY Posts.date_posted, Posts.time_posted DESC", session[:user]["id"])
    end

    # Get all comments on a post
    # 
    # @param [String] post_id, id of the original post
    # @returns [Array] returns an array of all comments on a given post
    def get_comments(post_id)
        db = get_dataBase()
        return db.execute("SELECT p.* FROM Posts AS p, Posts AS p2 WHERE p.posted_on = p2.id AND p2.id = #{post_id} ORDER BY likes DESC")
    end

    # Creates a post in the Posts table where Posts.posted_on is equal to the id of the original post the comment is on
    # 
    # @params [String] text, the text content of the comment
    # @param [String] post_id, id of the original post
    def post_comment(text, post_id)
        db = get_dataBase()
        db.execute("INSERT INTO Posts (user_id, posted_on, date_posted, time_posted, text) VALUES (?,?,?,?,?)", session[:user]["id"], post_id, Time.now.strftime("%d/%m/%Y"), Time.now.strftime("%H:%M"), text)
    end

    # Creates a row in Like_rel indicating that the logged in user has liked a certain post. Increases the number of likes in the Posts table
    # 
    # @param [String] post_id, id of the liked post
    def like_post(post_id)
        db = get_dataBase()
        db.execute("INSERT INTO Like_rel (post_id, user_id) VALUES (#{post_id}, #{session[:user]["id"]})")
        db.execute("UPDATE Posts SET likes = likes + 1 WHERE id = #{post_id}")
    end

    # Delete the row in the Like_rel table for a specific post the logged in user had previously liked. Also decreeses the postes number of likes in
    # 
    # @param [String] post_id, id of the post to unlike
    def unlike_post(post_id)
        db = get_dataBase()
        db.execute("DELETE FROM Like_rel WHERE post_id =  #{post_id}")
        db.execute("UPDATE Posts SET likes = likes - 1 WHERE id = #{post_id}")
    end

    # Gets the post with a given id in the Posts table
    # 
    # @param [String] post_id, id of the post
    # @returns [Hash] the hash of the post with the given id
    def get_post(post_id)
        db = get_dataBase()
        return db.execute("SELECT * FROM Posts WHERE id = #{post_id}").first
    end

    # Gets all posts in a post chain from a given startig point
    # 
    # @param [String] post_id, id of the starting post in the post chain
    # @returns [Array] returns an array of all posts in the chain begining with the starting post
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

    # Creates a post in the Posts table
    # 
    # @param [String] text, the text content of the new post
    def create_post(text)
        db = get_dataBase()
        # p "INSERT INTO Posts (user_id, text, posted_on, date_posted, time_posted) VALUES (#{session[:user]["id"]}, ?, '/', #{Time.now.strftime("%d/%m/%Y")}, #{Time.now.strftime("%H:%M")})"
        db.execute("INSERT INTO Posts (user_id, text, date_posted, time_posted) VALUES (#{session[:user]["id"]}, ?, '#{Time.now.strftime("%d/%m/%Y")}', '#{Time.now.strftime("%H:%M")}')", text)
    end

    # Removes the logged in users status for a given boulder in the Boulder_User_rel
    # 
    # @param [String] boulder_id, id of the boulder
    def untick_boulder(boulder_id)
        db = get_dataBase()
        db.execute("DELETE FROM Boulder_User_rel WHERE boulder_id = ?", boulder_id)
    end

    # Creates a row in the Boulder_User_rel table specifying the status between the logged in user and a given boulder
    # 
    # @param [String] boulder_id, id of the boulder
    # @param [String] type, the type of status
    def tick_boulder(boulder_id, type)
        # p type, "(#{boulder_id}, #{session[:user]["id"]}, #{type})"
        db = get_dataBase()
        db.execute("INSERT INTO Boulder_User_rel (boulder_id, user_id, type_of_rel) VALUES (#{boulder_id}, #{session[:user]["id"]}, '#{type}')")
    end

    # Clears a given table
    # 
    # @param [String] tablename, the name of the table
    def clear_table(tablename)
        db = get_dataBase()
        db.execute("DELETE FROM #{tablename}")
    end

    # Log in user
    # 
    # @param [String] username
    # @param [String] password
    def log_in(username, password)
        db = get_dataBase()
        password_from_db = db.execute("SELECT password_digest FROM Users WHERE username = ?", username).first
        # p password_from_db
        if password_from_db == nil
            session[:log_in_error] = "Username does not exist"
        elsif BCrypt::Password.new(password_from_db["password_digest"]) == password
            session[:user] = db.execute("SELECT * FROM Users WHERE username = ?", username).first
            # session[:log_in_error] = 
        else
            session[:log_in_error] = "Password is incorrect"
            if  session[:last_log_in_attempt] != nil && Time.now.sec - session[:last_log_in_attempt] < 10
                session[:recent_log_in_attempts] += 1
            else
                p "isugiyo<sg"
                session[:last_log_in_attempt] = Time.now.sec
                session[:recent_log_in_attempts] = 0
            end
            p session
        end
    end

    # Get password digest for a certain user given their username
    # 
    # @param [String] username
    # @returns [Hash] return a hash containing the password digest of a user given their name
    def select_password(username)
        db = get_dataBase()
        return db.execute("SELECT password_digest FROM Users WHERE username = ?", username).first
    end

    # Gets all users in the Users table
    # 
    # @returns [Array] returns an array of all users in the Users table
    def get_users()
        db = get_dataBase()
        return db.execute("SELECT username FROM Users")
    end

    # Creates a new user in the Users table
    # 
    # @param [String] new_username, the username of the new account
    # @param [String] password_digest, the encrypted password of the new account
    def create_user(new_username, password_digest)
        db.execute("INSERT INTO Users (username, password_digest) VALUES (?,?)",new_username, password_digest)
    end

    # Logs a user in and stores their informaiton in session
    # 
    # @param [String] username
    def log_in_username(username)
        session[:user] = db.execute("SELECT * FROM Users WHERE username = ?", username).first
    end

    # Finds the results from a search
    # 
    # @param [String] search_input, the search term
    # @returns [Array] returns an array of all relevant search results ranked by their relevance to the search
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

    # Updates the bio of the logged in user
    # 
    # @param [String] new_bio, the new text in the bio
    def update_bio(new_bio)
        db = get_dataBase()
        db.execute("UPDATE Users SET bio = ? WHERE id = #{session[:user]["id"]}", new_bio)
    end 

    # Creates a new row in the Follower_rel showing the logged in user followed another user. The follower count of the other user goes upp by one.
    # 
    # @param [String] user_to_follow_id, id of the user to follow
    def follow(user_to_follow_id)
        db = get_dataBase()
        db.execute("INSERT INTO Follower_rel VALUES (#{user_to_follow_id}, #{session[:user]["id"]})")
        db.execute("UPDATE Users SET followers = #{db.execute("SELECT followers FROM Users  where id = ?", user_to_follow_id).first["followers"] + 1} WHERE id = ?", user_to_follow_id)
    end

    # Deletes a row in the Follower_rel which previously showed the logged in user followed another user. The follower count of the other user goes down by one.
    # 
    # @param [String] user_to_unfollow_id, id of the user to unfollow
    def unfollow(user_to_unfollow_id)
        db = get_dataBase()
        db.execute("DELETE FROM Follower_rel WHERE (user_id, followed_by_id) = (?,?)", user_to_unfollow_id, session[:user]["id"])
        db.execute("UPDATE Users SET followers = #{db.execute("SELECT followers FROM Users  where id = ?", user_to_unfollow_id).first["followers"] - 1} WHERE id = ?", user_to_unfollow_id)
    end

    # Gets a boudler from Boulder with a given name
    # 
    # @param [String] boulder_name, the name of the boudler
    # @returns [Hash] returns a hash of the boulder
    def get_boulder_from_name(boulder_name)
        db = get_dataBase()
        return db.execute("SELECT * FROM Boulders WHERE name = ?", boulder_name).first
    end

    # Creates a new boulder in the Boulder table¨
    # 
    # @param [String] boulder_name, name of the new boulder
    # @param [String] grade, difficulty grade in the V-scale of the boulder
    # @param [String] location, the location of the new boulder
    # @param [String] description, the description of the boudler
    # @param [String] path, the file path for the boudlers thumbnail image
    def create_boulder(boulder_name, grade, location, description, path)
        db = get_dataBase()
        db.execute("INSERT INTO Boulders (name, location, first_ascent, description, grade, pic_path) VALUES (?,?,?,?,?,?)", boulder_name, location, session[:user]["username"], description, grade, path)
    end

    # Gets user from the Users table given a username
    # 
    # @param [String] username
    # @returns [Hash] a hash containing the user info
    def get_user_from_username(username)
        db = get_dataBase()
        return db.execute("SELECT * FROM Users WHERE username = ?", username).first
    end

    # lets the methods contained within be seen in the slim files
    # 
    # helpers do
    #     # Get content given a set of conditions
    #     # 
    #     # @param [String] requested_cont, the content requested in the sql query
    #     # @param [String] table, name of the table the content is requested from
    #     # @param [String] condition, a column of the table
    #     # @param [String] var, the value of the condition column
    #     # @returns [Hash] returns a hash containing the content from the table
    #     def get_where(requested_cont, table, condition, var)
    #         db = get_dataBase()
    #         # p "SELEaewfCT #{requested_cont} FROM #{table} WHERE #{condition} = #{var}"
    #         return db.execute("SELECT #{requested_cont} FROM #{table} WHERE #{condition} = ?",var)
    #     end

    #     # Checks if the logged in user has ticked a give boulder
    #     # 
    #     # @param [Hash] boulder, hash of the boulder info in the Boudler table
    #     # @returns [Booelan] returns true if the logged in user has ticked the boulder and false otherwise
    #     def ticked?(boulder)
    #         if session[:user] != nil
    #             db = get_dataBase()
    #             # p db.execute("SELECT * FROM Boulder_User_rel INNER JOIN Users ON Boulder_User_rel.user_id = Users.id WHERE Users.id = #{session[:user]["id"]} AND Boulder_User_rel.boulder_id = #{boulder["id"]}")
    #             if db.execute("SELECT * FROM Boulder_User_rel INNER JOIN Users ON Boulder_User_rel.user_id = Users.id WHERE Users.id = #{session[:user]["id"]} AND Boulder_User_rel.boulder_id = #{boulder["id"]}").length > 0
    #                 return true
    #             end
    #         end
    #         return false
    #     end

    #     # Gets the tick type of a boulder for a certain user
    #     # 
    #     # @param [Hash] boulder, hash of the boulder info in the Boudler table
    #     # @param [String] user_id, id of the user
    #     # @returns [String] returns the type of tick from the Boulder_User_rel table
    #     def tick_type(boulder, user_id)
    #         db = get_dataBase
    #         tick_type = db.execute("SELECT type_of_rel FROM Boulder_User_rel WHERE boulder_id = #{boulder["id"]} AND user_id = #{user_id}").first
    #         return tick_type["type_of_rel"]
    #     end

    #     # Checks if a user follows another specified user
    #     # 
    #     # @param [String] user_id, id of the potentiolly followed user
    #     # @param [String] follower_id, id of the user who potentially follows the other
    #     # @returns [Boolean] returns true if the second user follows the first and false otherwise
    #     def follows?(user_id, follower_id)
    #         db = get_dataBase()
    #         check = db.execute("SELECT * FROM Follower_rel WHERE (user_id, followed_by_id) = (?,?)", user_id, follower_id)
    #         # p check
    #         if check != []
    #             return true
    #         else
    #             return false
    #         end
    #     end

    #     # Gets all boulders from the Boulder table
    #     # 
    #     # @returns [Array] returns an array of all boulders in the Boulder table
    #     def get_boulders()
    #         db = get_dataBase()
    #         boulders = db.execute("SELECT * FROM Boulders")
    #     end

    #     # Gets all boulders the user has ticked
    #     # 
    #     # @param [String] user_id, id of the user
    #     # @returns [Array] returns an array of all boulders the user has ticked
    #     def get_boulders_sent(user_id)
    #         # p "detta händer"
    #         db = get_dataBase()
    #         # # p db.execute("SELECT * FROM Problems WHERE id LIKE Problem_User_rel.problem_id AND Problem_User_rel.user_id = ?", user_id)
    #         # boulder_data = []
    #         # # db.execute("SELECT * FROM Boulder_User_rel WHERE user_id = #{user_id}").each do |boulder_id|
    #         # #     boulder_data << db.execute("SELECT * FROM Boulders WHERE id = #{boulder_id}").first
    #         # # end
    #         return db.execute("SELECT * FROM Boulders INNER JOIN Boulder_User_rel On Boulders.id = Boulder_User_rel.boulder_id WHERE Boulder_User_rel.user_id = #{user_id}")
    #     end

    #     # Gets all posts from a user
    #     # 
    #     # @param [String] user_id, id of the user
    #     # @returns [Array] an array of all posts from the user
    #     def get_posts_from_user(user_id)
    #         db = get_dataBase()
    #         return db.execute("SELECT * FROM Posts WHERE user_id = ? ORDER BY Posts.date_posted, Posts.time_posted DESC ", user_id)
    #     end

    #     # Gets a hash containing the info related to a user in the Users table given the user id
    #     # 
    #     # @param [String] user_id, id of the user
    #     # @returns [Hash] returns a hash containing the info related to a user in the Users table given the user id
    #     def get_user(user_id)
    #         db = get_dataBase()
    #         return db.execute("SELECT * FROM Users WHERE id = ?", user_id).first
    #     end 

    #     # Gets the five most followed people a user is following
    #     # 
    #     # @param [String] user_id, id of the user
    #     # @returns [Arrat] returns an orderd array of the five most followed users the given user is following
    #     def get_top_5_follows(user_id)
    #         db = get_dataBase()
    #         ordered_follows = db.execute("SELECT * FROM Follower_rel AS Fr INNER JOIN Users ON Users.id = Fr.user_id WHERE followed_by_id = #{user_id} ORDER BY Users.followers DESC")
    #         if ordered_follows.length < 5
    #             return ordered_follows
    #         else
    #             # p ordered_follows[0..5]
    #             return ordered_follows[0..4]
    #         end
    #     end
        
    #     # Chekcs if a post is liked by the logged in user
    #     # 
    #     # @param [String] post_id, id of the post
    #     # @returns [Boolean] returns true if the post is liked by the logged in user and false if not
    #     def is_liked(post_id)
    #         # p post_id
    #         db = get_dataBase()
    #         # p "SELECT * FROM Like_rel WHERE post_id = #{post_id} AND user_id = #{session[:user]["id"]}"
    #         # p db.execute("SELECT * FROM Like_rel WHERE post_id = #{post_id} AND user_id = #{session[:user]["id"]}").length != 0
    #         return db.execute("SELECT * FROM Like_rel WHERE post_id = #{post_id} AND user_id = #{session[:user]["id"]}").length != 0
    #     end

    #     # Finds the number of likes for a given post
    #     # 
    #     # @param [String] post_id, id of the post
    #     # @returns [Integer] returns the number of likes on the post
    #     def number_of_likes(post_id)
    #         db = get_dataBase()
    #         return db.execute("SELECT likes FROM Posts WHERE id = #{post_id}").first["likes"]
    #     end

    #     # Gets the hash containing info about the user who posted a certain post
    #     # 
    #     # @param [String] post_id, id of the post
    #     # @returns [Hash] returns the hash containing info about the user who posted a certain post
    #     def get_poster(post_id)
    #         db = get_dataBase()
    #         return db.execute("SELECT Users.* FROM Users INNER JOIN Posts ON Posts.user_id = Users.id WHERE Posts.id = ?", post_id).first
    #     end
    # end
end

