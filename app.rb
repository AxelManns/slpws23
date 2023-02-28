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

def rank(array, term)
    sorted_arr = []
    array.each do |item|
        score = 0
        i = 0
        while item[i..i + term.length-1].downcase != term
            i += 1
        end
        # kollar hur stor del av item som är termen vi söker efter och vart i item som termen ligger för att ranka hur bra de olika itemsen matchar termen
        score = (term.length.to_f / item.length.to_f + (item.length - 1 - i.to_f) / (item.length.to_f - 1))/2
        if sorted_arr.length != 0 
            i = 0
            # p sorted_arr[i]
            while i < sorted_arr.length && sorted_arr[i][1] >= score
                # p sorted_arr[i]
                i += 1
            end
            if i != 0
                sorted_arr = sorted_arr[0..i] + [[item, score]] + sorted_arr[i..sorted_arr.length]
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
    p password_from_db
    if password_from_db == nil
        session[:log_in_error] = "Username does not exist"
    elsif BCrypt::Password.new(password_from_db["password_digest"]) == password
        session[:user] = db.execute("SELECT * FROM Users WHERE username = ?", username).first
    else
        session[:log_in_error] = "Password is incorrect"
    end
    p session[:current_route]
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
        result_ids = {"Users" => [], "Problems" => []}
        [{:table_name => "Users", :variables => ["username"]}, {:table_name => "Problems", :variables => ["name", "description"]}].each do |table|
            table[:variables].each do |variable|
                # p table, variable
                content = db.execute("SELECT #{variable} FROM #{table[:table_name]} WHERE #{variable} LIKE '%#{search_input}%'")
                content.each do |item|
                    results[table[:table_name]] << item["username"]
                end
                results[table[:table_name]] = rank(results[table[:table_name]], search_input)
                # p results
                results[table[:table_name]].each do |result|
                    result_ids[table[:table_name]] << db.execute("SELECT id FROM #{table[:table_name]} WHERE #{variable} = ?", result).first["id"]
                end

                # if content.includes?(search_input)
            end
        end
        slim(:search_results, locals:{result_ids:result_ids})
    end
end

get('/profile/:username') do
    # p session[:current_route]
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
    redirect('profile/self/edit')
end

post("/follow/:user_to_follow") do
    user_to_follow_id = params[:user_to_follow]
    db = get_dataBase()
    # p session["user"]
    #  (User_id, Followed_by_user_id)
    # p db.execute("SELECT followers FROM Users  where id = ?", user_to_follow_id).first
    db.execute("INSERT INTO Follower_rel VALUES (#{user_to_follow_id}, #{session[:user]["id"]})")
    db.execute("UPDATE Users SET followers = #{db.execute("SELECT followers FROM Users  where id = ?", user_to_follow_id).first["followers"] + 1} WHERE id = ?", user_to_follow_id)
    redirect("/profile/#{db.execute("SELECT username FROM Users WHERE id = #{user_to_follow_id}").first["username"]}")
end

post("/unfollow/:user_to_unfollow_id") do
    user_to_unfollow_id = params[:user_to_unfollow_id]
    db = get_dataBase()
    # p session["user"]
    # #  (User_id, Followed_by_user_id)
    # p db.execute("SELECT followers FROM Users  where id = ?", user_to_follow_id).first
    db.execute("DELETE FROM Follower_rel WHERE (user_id, followed_by_id) = (?,?)", user_to_unfollow_id, session[:user]["id"])
    db.execute("UPDATE Users SET followers = #{db.execute("SELECT followers FROM Users  where id = ?", user_to_unfollow_id).first["followers"] - 1} WHERE id = ?", user_to_unfollow_id)
    redirect("/profile/#{db.execute("SELECT username FROM Users WHERE id = #{user_to_unfollow_id}").first["username"]}")
end

get('/problem') do
    slim(:problem)
end

# clear_table("Follower_rel")