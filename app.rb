require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'

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
        session[:raise_error] = true
        session[:error_message] = "Username does not exist"
    elsif BCrypt::Password.new(password_from_db["password_digest"]) == password
        session[:user] = db.execute("SELECT * FROM Users WHERE username = ?", username).first
    else
        session[:raise_error] = true
        session[:error_message] = "Password is incorrect"
    end
    redirect("#{session[:last_route_visited]}")
end

post('/log_out') do 
    session[:user] = nil
    redirect("#{session[:last_route_visited]}")
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
    db = get_dataBase()
    # results = {:Users => [], :Problems => []}
    results = {"Users" => [], "Problems" => []}
    result_ids = {"Users" => [], "Problems" => []}
    [{:table_name => "Users", :variables => ["username"]}, {:table_name => "Problems", :variables => ["name", "description"]}].each do |table|
        table[:variables].each do |variable|
            p table, variable
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

get('/problem') do
    slim(:problem)
end