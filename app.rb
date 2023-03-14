require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './model.rb'

enable :sessions

before do
    # p request.path_info, request.request_method
    if request.request_method == "GET"
        if session[:current_route] != nil
            session[:last_route_visited] = session[:current_route]
        end
        session[:current_route] = request.path_info
    end
    p session[:current_route]
end

# def change_routes(current_route)
#     session[:last_route_visited] = session[:current_route]
#     session[:current_route] = current_route
# end

def get_dataBase()
    db = SQLite3::Database.new("db/Database.db")
    db.results_as_hash = true
    return db
end

def update_user_info()
    db = get_dataBase()
    session[:user] = db.execute("SELECT * FROM Users WHERE id = ?", session[:user]["id"]).first
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

def rank_with_id(inp_array, term)
    array = inp_array.dup
    # p array
    sorted_arr = []
    array.each do |item|
        p item["variable"]
        score = 0
        i = 0
        # p item["variable"][i..i + term.length-1]
        while i + term.length < item["variable"].length && item["variable"][i..i + term.length-1].downcase != term
            i += 1
            # p item["variable"][i..i + term.length-1]
        end
        # kollar hur stor del av item som är termen vi söker efter och vart i item som termen ligger för att ranka hur bra de olika itemsen matchar termen
        if item["variable"].length > 1
            score = (term.length.to_f / item["variable"].length.to_f + (item["variable"].length - 1 - i.to_f) / (item["variable"].length.to_f - 1))/2
        else
            score = 1
        end
        # p item, score 
        if sorted_arr.length != 0 
            # p sorted_arr
            i = 0
            while i < sorted_arr.length && sorted_arr[i][1] >= score
                p sorted_arr[i][1]
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

get('/') do
    slim(:main)
end

post('/log_in') do
    username = params["username"]
    password = params["password"]
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
    redirect("#{session[:current_route]}")
end

post('/log_out') do 
    session[:user] = nil
    redirect("#{session[:current_route]}")
end

get('/users/new') do
    # if session[:last_route_visited] == nil
    #     session[:last_route_visited] = "/users/new"
    # end
    # change_routes(request.path_info)
    slim(:register)
end

post('/users') do
    new_username = params["username"]
    password = params["password"]   
    password_conf = params["password_confirmation"]
    db = get_dataBase()
    username_arr = db.execute("SELECT username FROM Users")
    i = 0
    username_exists = false
    while i < username_arr.length && username_exists == false
        if username_arr[i]["username"] == new_username
            username_exists = true
        end
        i += 1
    end
    if username_exists
        session[:raise_error] = true
        session[:error_message] = "Username is already taken"
        redirect("/users/new")
    elsif password.length < 8
        session[:raise_error] = true
        session[:error_message] = "password must be atleast 8 characters long"
        redirect("/users/new")
    elsif password != password_conf
        session[:raise_error] = true
        session[:error_message] = "Passwords must match"
        redirect("/users/new")
    end
    password_digest = BCrypt::Password.create(password)
    db.execute("INSERT INTO Users (username, password_digest) VALUES (?,?)",new_username, password_digest)
    session[:user] = db.execute("SELECT * FROM Users WHERE username = ?", new_username).first
    redirect("#{session[:last_route_visited]}")
end

get('/search') do
    search_input = params[:search_input]
    session[:current_route] = "/search?search_input=#{search_input}"
    # kunde inte få request.path_info att ta med hela pathen så var tvungen att manuelt ta med vad search inputen var lika med
    session[:current_route] = request.path_info + "?search_input=#{search_input}"
    if search_input == ""
        session[:search_error] = "Cannot search without input"
        redirect(session[:last_route_visited])
    else
        db = get_dataBase()
        # results = {:Users => [], :Problems => []}
        results = {"Users" => [], "Problems" => []}
        result_data_array = {"Users" => [], "Problems" => []}
        [{:table_name => "Users", :variables => ["username"]}, {:table_name => "Problems", :variables => ["name", "location"]}].each do |table|
            # table[:variables].each do |variable|
            #     # p table, variable
            #     content = db.execute("SELECT #{variable} FROM #{table[:table_name]} WHERE #{variable} LIKE '%#{search_input}%'")
            #     p content
            #     content.each do |item|
            #         # p item[variable]
            #         results[table[:table_name]] << item[variable]
            #     end
            #     p results
            #     results[table[:table_name]] = rank(results[table[:table_name]], search_input)
            #     results[table[:table_name]].each do |result|
            #         # p result, "resultat"
            #         # p db.execute("SELECT id FROM #{table[:table_name]} WHERE #{variable} = ?", result), variable
            #         if db.execute("SELECT * FROM #{table[:table_name]} WHERE #{variable} = ?", result).first != nil
            #             result_array[table[:table_name]] << db.execute("SELECT * FROM #{table[:table_name]} WHERE #{variable} = ?", result).first
                        
            #         end
            #     end
            #     # if content.includes?(search_input)
            #     # p result_array
            # end
            query = ""
            table[:variables].each_with_index do |variable, i|
                if i > 0
                    query += " OR #{variable} LIKE '%#{search_input}%'"
                else
                    query += "#{variable} LIKE '%#{search_input}%'"
                end
            end
            p "SELECT * FROM #{table[:table_name]} WHERE #{query}"
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
            p unsorted_result
            results[table[:table_name]] = rank_with_id(unsorted_result, search_input)
            results[table[:table_name]].each do |result|
                result_data_array[table[:table_name]] << db.execute("SELECT * FROM #{table[:table_name]} WHERE id LIKE ?", result["id"]).first
            end
        end
        p result_data_array
        slim(:search_results, locals:{result_array:result_data_array})
    end
end

get('/profile/:username') do
    username = params[:username]
    user_data = get_where("*", "Users", "username", username).first
    # p user_data
    slim(:"profile/show", locals:{user_data:user_data})
end

get('/profile/self/edit') do
    slim(:"profile/edit")
end
post('/change_profile_pic') do
    # p params[:file]
    path = File.join("./public/uploaded_pictures/",params[:file][:filename])
    File.write(path,File.read(params[:file][:tempfile]))
    # db = get_dataBase()
    # p path
    # db.execute("UPDATE Users SET profile_pic = path")
    update_user_info()
    redirect('profile/self/edit')
end

post('/change_bio') do
    new_bio = params[:new_bio]
    db = get_dataBase()
    db.execute("UPDATE Users SET bio = ? WHERE id = #{session[:user]["id"]}", new_bio)
    update_user_info()
    redirect('profile/self/edit')
end

post("/follow/:user_to_follow") do
    user_to_follow_id = params[:user_to_follow]
    db = get_dataBase()
    db.execute("INSERT INTO Follower_rel VALUES (#{user_to_follow_id}, #{session[:user]["id"]})")
    db.execute("UPDATE Users SET followers = #{db.execute("SELECT followers FROM Users  where id = ?", user_to_follow_id).first["followers"] + 1} WHERE id = ?", user_to_follow_id)
    redirect(session[:current_route])
end

post("/unfollow/:user_to_unfollow_id") do
    user_to_unfollow_id = params[:user_to_unfollow_id]
    db = get_dataBase()
    db.execute("DELETE FROM Follower_rel WHERE (user_id, followed_by_id) = (?,?)", user_to_unfollow_id, session[:user]["id"])
    db.execute("UPDATE Users SET followers = #{db.execute("SELECT followers FROM Users  where id = ?", user_to_unfollow_id).first["followers"] - 1} WHERE id = ?", user_to_unfollow_id)
    # redirect("/profile/#{db.execute("SELECT username FROM Users WHERE id = #{user_to_unfollow_id}").first["username"]}")
    redirect(session[:current_route])
end

get('/problems/show') do
    slim(:"problems/index")
end

get('/problems/show/:boulder_name') do 
    boulder_name = params[:boulder_name]
    db = get_dataBase()
    boulder_data = db.execute("SELECT * FROM Problems WHERE name = ?", boulder_name).first
    slim(:"problems/show", locals:{boulder_data:boulder_data})
end

get('/problems/new') do 
    slim(:"problems/new")
end

post('/problems') do
    db = get_dataBase()
    if params[:file] != nil
        path = File.join("./public/uploaded_pictures/",params[:file][:filename])
        File.write(path,File.read(params[:file][:tempfile]))
    else
        path = "/img/no-image-found.png"
    end
    boulder_name = params[:boulder_name]
    grade = params[:grade]
    location = params[:location]
    description = params[:description]
    p boulder_name, location, session[:user]["id"], description, grade, path

    db.execute("INSERT INTO Problems (name, location, set_by, description, grade, pic_path) VALUES (?,?,?,?,?,?)", boulder_name, location, session[:user]["id"], description, grade, path)
    redirect("/problems/show/#{boulder_name}")
end

def rank_relevance(posts)
    return posts
end

get('/feed') do
    db = get_dataBase()
    if session[:user] == nil
        return "<p>must be logged in to view this content</p>"
    end
    follows_id = db.execute("SELECT user_id FROM Follower_rel WHERE followed_by_id = #{session[:user]["id"]}")
    p follows_id
    relevant_posts = []
    follows_id.each do |id_following|
        content = db.execute("SELECT * FROM Posts WHERE user_id = #{id_following["user_id"]}")
        if content.length > 0
            relevant_posts << content
        end
    end
    relevant_posts = rank_relevance(relevant_posts)
    p relevant_posts
    slim(:feed, locals:{relevant_posts:relevant_posts})
end

# clear_table("Follower_rel")