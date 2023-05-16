require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './model.rb'

include Model

enable :sessions

before do
    # p request.path_info, request.request_method
    if request.request_method == "GET"
        if session[:current_route] != nil
            session[:last_route_visited] = session[:current_route]
        end
        session[:current_route] = request.path_info
    end
    # p session[:current_route]
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
        # p item["variable"]
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
                # p sorted_arr[i][1]
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
    if (session[:log_in_time_out] == nil || (Time.now - session[:log_in_time_out]) >= 0) && session[:recent_log_in_attempts] != nil && session[:recent_log_in_attempts] >= 3
        session[:log_in_time_out] = Time.now + 20
        session[:recent_log_in_attempts] = 0
    end
    # p session[:recent_log_in_attempts]
    if  session[:log_in_time_out] == nil || Time.now - session[:log_in_time_out] >= 0
        username = params["username"]
        password = params["password"]
        password_from_db = select_password(username)
        # p password_from_db
        if password_from_db == nil
            session[:log_in_error] = "Username does not exist"
        elsif BCrypt::Password.new(password_from_db["password_digest"]) == password
            session[:user] = get_user_from_username(username)
            # session[:log_in_error] = 
        else
            session[:log_in_error] = "Password is incorrect"
        end
        if  session[:log_in_error] != "" && session[:last_log_in_attempt] != nil && Time.now.sec - session[:last_log_in_attempt] < 10
            session[:recent_log_in_attempts] += 1
        else
            # p "isugiyo<sg"
            session[:last_log_in_attempt] = Time.now
            session[:recent_log_in_attempts] = 0
        end
        # p session
        # p "log in error medelandet är:", session[:log_in_error]
    else
        session[:log_in_error] = "To many failde attempts to log in, wait #{(session[:log_in_time_out] - Time.now).to_i}"
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
    username_arr = get_users()
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
    elsif new_username.length > 20
        session[:raise_error] = true
        session[:error_message] = "Username is longer then 20 characters"
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
    create_user(new_username, password_digest)
    log_in_username(new_username)
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
        result_data_array = find_search_results(search_input)
        # p result_data_array
        slim(:search_results, locals:{result_array:result_data_array})
    end
end

get('/profile/:username') do
    username = params[:username]
    user_data = get_where("*", "Users", "username", username).first
    # p user_data
    slim(:"users/show", locals:{user_data:user_data})
end

get('/profile/self/edit') do
    if session[:user] == nil
        slim(:not_access)
    else
        slim(:"users/edit")
    end
end
post('/change_profile_pic/:user_id') do
    # p params[:file]
    if session[:user]["id"] == params[:user_id]
        path = File.join("./public/uploaded_pictures/",params[:file][:filename])
        File.write(path,File.read(params[:file][:tempfile]))
        update_user_info(path)
    end
    redirect('profile/self/edit')
end

post('/change_bio/:user_id') do
    if session[:user]["id"] == params[:user_id].to_i
        p "awlirehbgilawrbljhwrabvljhawer"
        new_bio = params[:new_bio]
        update_bio(new_bio)
        update_user_info()
    end
    redirect('profile/self/edit')
end

post("/follow/:user_to_follow") do
    user_to_follow_id = params[:user_to_follow]
    follow(user_to_follow_id)
    # p "current rout is: " + session[:current_route] + ", and the previous route is: " + session[:last_route_visited]
    redirect(session[:current_route])
end

post("/unfollow/:user_to_unfollow_id") do
    user_to_unfollow_id = params[:user_to_unfollow_id]
    unfollow(user_to_unfollow_id)
    # redirect("/profile/#{db.execute("SELECT username FROM Users WHERE id = #{user_to_unfollow_id}").first["username"]}")
    redirect(session[:current_route])
end

get('/boulders/show') do
    if session[:user] != nil
        slim(:"boulders/index")
    else
        slim(:log_in_error)
    end
end

get('/boulders/show/:boulder_name') do 
    boulder_name = params[:boulder_name]
    boulder_data = get_boulder_from_name(boulder_name)
    slim(:"boudlers/show", locals:{boulder_data:boulder_data})
end

get('/boulders/new') do 
    slim(:"boulders/new")
end

post('/boulders') do
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
    # p boulder_name, location, session[:user]["id"], description, grade, path

    create_boulder(boudler_name, grade, location, description, path)
    redirect("/boulders/show/#{boulder_name}")
end

get('/feed') do
    if session[:user] == nil
        slim(:log_in_error)
    else
        relevant_posts = get_relevent_posts()
        slim(:feed, locals:{relevant_posts:relevant_posts})
    end
end

post('/tick/:boulder_id/:type') do
    boulder_id = params[:boulder_id]
    type = params[:type]
    if type == "flashed" || type == "sent" || type == "not_sent"
        tick_boulder(boulder_id, type)
        post_boulder(type, boulder_id)
    end
    redirect(session[:current_route])
end

post('/untick/:boulder_id') do 
    boulder_id = params[:boulder_id].to_i
    untick_boulder(boulder_id)
    redirect(session[:current_route])
end

post('/posts') do
    text = params[:new_post_text]
    create_post(text)
    redirect(session[:current_route])
end

get('/post/show/:post_id') do
    post_id = params[:post_id]
    post_chain = get_post_chain(post_id)
    p "post chain is:",post_chain
    comments = get_comments(post_id)
    slim(:"posts/show", locals:{post_chain:post_chain, comments:comments})
end

post('/like_post/:post_id') do
    post_id = params[:post_id]
    like_post(post_id)
    redirect(session[:current_route])
end

post('/unlike_post/:post_id') do
    post_id = params[:post_id]
    unlike_post(post_id)
    redirect(session[:current_route])
end

post('/comment/:commented_on_id') do 
    commented_on_id = params[:commented_on_id]
    text = params[:new_comment_text]
    post_comment(text, commented_on_id)
    redirect(session[:current_route])
end

get('/manege_posts') do
    if session[:user] != nil && session[:user]["permission"] == "admin"
        posts = get_all_posts()
        slim(:"posts/manege", locals:{posts:posts})
    else
        redirect(session[:last_route_visited])
    end
end

post('/posts/update/:post_id') do
    post_id = params[:post_id]
    new_text = params[:new_text]
    update_text(post_id, new_text)
    redirect(session[:current_route])
end

post('/posts/delete/:post_id') do
    post_id = params[:post_id]
    if session[:user]["permission"] == "admin" || session[:user]["id"] == get_poster(post_id)
        delete_post(post_id)
    end
    redirect(session[:current_route])
end

get('/posts/edit/:post_id') do
    post_id = params[:post_id]
    post = get_post(post_id)
    if session[:user] == nil || post["user_id"] != session[:user]["id"]
        slim(:not_access) 
    else 
        slim(:"posts/edit", locals:{post:post})
    end
end

# clear_table("Like_rel")
# clear_table("Posts")
# clear_table("Follower_rel")