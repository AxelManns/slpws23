require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'

enable :sessions

get('/') do
    slim(:main)
end

get('/users/new') do
    if session[:last_route_visited] == nil
        session[:last_route_visited] = "/users/new"
    end
    slim(:register)
end

post('/users') do
    new_username = params["username"]
    password = params["password"]   
    password_conf = params["password_confirmation"]
    db = SQLite3::Database.new("db/Database.db")
    db.results_as_hash = true
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

