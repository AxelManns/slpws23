require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'

enable :sessions

before do
    p request.request_method
end

def change_routes(current_route)
    session[:last_route_visited] = session[:current_route]
    session[:current_route] = current_route
end

def get_dataBase()
    db = SQLite3::Database.new("db/Database.db")
    db.results_as_hash = true
    return db
end

get('/') do
    change_routes('/')
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
    if session[:last_route_visited] == nil
        session[:last_route_visited] = "/users/new"
    end
    change_routes(request.path_info)
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

