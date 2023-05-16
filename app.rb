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

# Sorts an Array of strings in descending order based on each elements resemblence to a given string
# 
# @param inp_array [Array] Input array
# @param term [String] string to sort based off of
# @return [Array] returns the input array sorted by the resemblance to the input term in descending order
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

# Sorts a given array based on each elements similarity to a given string. Each element is a hash containing a variable string and an id. The string is used to compere.
# 
# @param [String] inp_array, the input array
# @param [String] term, the string to order all elements by
# @returns [Array] returns the sorted array
def rank_with_id(inp_array, term)
    array = inp_array.dup
    # p array
    sorted_arr = []
    array.each do |item|
        p item
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

# Displayes the starting page
# 
get('/') do
    slim(:main)
end

# Saves a users information in session and thereby logs the user in
# 
# @param [String] The username of the account attempting to be logged into
# @param [String] The raw password used to attempt to log in
# @see Model#select_password
# @see Model#get_user_from_username
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
        if  session[:log_in_error] != "" && session[:last_log_in_attempt] != nil && Time.now - session[:last_log_in_attempt] < 10
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

# Discards user data in session and thereby logs the user out
# 
post('/log_out') do 
    session[:user] = nil
    redirect("#{session[:current_route]}")
end

# Displayes the page for users to register new accounts
# 
get('/users/new') do
    # if session[:last_route_visited] == nil
    #     session[:last_route_visited] = "/users/new"
    # end
    # change_routes(request.path_info)
    slim(:register)
end

# Attemps to create a new account with a given username and password, and the logs into said account if creation is successfull
# 
# @param [String] username
# @param [String] password
# @see Model#get_user
# @see Model#create_user
# @see Model#log_in_username
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

# Displayes the search results page
# 
# @param [String] search_input, the input string used ot search for relevant content in the database
# @see Model#finde_search_results
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

# Displayes profile page of a user
# 
# @param [String] :username, the username of the user
# @see Model#get_where
get('/profile/:username') do
    username = params[:username]
    user_data = get_where("*", "Users", "username", username).first
    # p user_data
    slim(:"users/show", locals:{user_data:user_data})
end

# Displayes the profile edit page for a users own profile page
# 
get('/profile/self/edit') do
    if session[:user] == nil
        slim(:not_access)
    else
        slim(:"users/edit")
    end
end

# Upploads an image into the public/uploaded_pictures map and updates a users own profile picture to become said image
# 
# @param [File] the image file
# @see Model#update_user_info
post('/change_profile_pic/:user_id') do
    # p params[:file]
    if session[:user]["id"] == params[:user_id]
        path = File.join("./public/uploaded_pictures/",params[:file][:filename])
        File.write(path,File.read(params[:file][:tempfile]))
        update_user_info(path)
    end
    redirect('profile/self/edit')
end

# Upploads an image into the public/uploaded_pictures map and updates a users own profile banner to become said image
# 
# @param [Integer] :use_id, the id of the user whose bio is to be changed
# @param [String] :new_bio, the new bio of the user
# @see Model#update_bio
# @see Model#update_user_info
post('/change_bio/:user_id') do
    if session[:user]["id"] == params[:user_id].to_i
        # p "awlirehbgilawrbljhwrabvljhawer"
        new_bio = params[:new_bio]
        update_bio(new_bio)
        update_user_info()
    end
    redirect('profile/self/edit')
end

# Creates a new row in the Follower_rel table that indicates that the logged in user is following a given user, the follower count of said user also increases by one
# 
# @parans [String] :user_to_follow, the id of the user that is to be followed
# @see Model#follow
post("/follow/:user_to_follow") do
    user_to_follow_id = params[:user_to_follow]
    follow(user_to_follow_id)
    # p "current rout is: " + session[:current_route] + ", and the previous route is: " + session[:last_route_visited]
    redirect(session[:current_route])
end

# Deletes the row in the Follower_rel table indicating the logged in user is following another user and reduses their follower count by one
# 
# params [String] :user_to_unfollow, the id of the user tha is to be unfollowed
# @see Model#unfollow
post("/unfollow/:user_to_unfollow_id") do
    user_to_unfollow_id = params[:user_to_unfollow_id]
    unfollow(user_to_unfollow_id)
    # redirect("/profile/#{db.execute("SELECT username FROM Users WHERE id = #{user_to_unfollow_id}").first["username"]}")
    redirect(session[:current_route])
end

# Displayes the list of all boulders ticket by the logged in user
# 
# @see Model#get_boulders_sent
get('/boulders/show') do
    if session[:user] != nil
        boulders_sent = get_boulders_sent(session[:user]["id"])
        slim(:"boulders/index", locals:{boulders_sent:boulders_sent})
    else
        slim(:not_access)
    end
end

# Displayes the page for a given boulder
# 
# @param [String] :boulder_name, the name of the boulder
# @see Model#get_boulder_from_name
get('/boulders/show/:boulder_name') do 
    boulder_name = params[:boulder_name]
    boulder_data = get_boulder_from_name(boulder_name)
    slim(:"boulders/show", locals:{boulder_data:boulder_data})
end

# Displayes the page for estableshing new boulders
# 
get('/boulders/new') do 
    slim(:"boulders/new")
end

# Creates a new boulder in the Boulder table
# 
# @param [File] :file, the thumbnail image for the boulder
# @param [String] :boulder_name, the name of the boulder 
# @param [String] :grade, the difficulty grading of the boulder in the V-scale
# @param [String] :location, the location of the boulder
# @param [String] :description, a description of the boulder
# @see Model#create_boulder
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

    create_boulder(boulder_name, grade, location, description, path)
    redirect("/boulders/show")
end

# Displayes the soical feed page
# 
# @see Model#get_relevant_posts
get('/feed') do
    if session[:user] == nil
        slim(:log_in_error)
    else
        relevant_posts = get_relevent_posts()
        slim(:feed, locals:{relevant_posts:relevant_posts})
    end
end

# Marks that a user has flashed, completed or not completed a boulder and posts an announcment of the status update in the feed
# 
# @param [String] :boulder_id, the id of the boulder to be ticked
# @param [String] :type, the type of tick. Flashed, sent or not sent
# @see Model#tick_boulder
# @see Model#post_boulder
post('/tick/:boulder_id/:type') do
    boulder_id = params[:boulder_id]
    type = params[:type]
    if type == "flashed" || type == "sent" || type == "not_sent"
        tick_boulder(boulder_id, type)
        post_boulder(type, boulder_id)
    end
    redirect(session[:current_route])
end

# Unticks a previously ticked boulder
# 
# @param [String] :boulder_id, the id of the boulder
# @see Model#untick_boulder
post('/untick/:boulder_id') do 
    boulder_id = params[:boulder_id].to_i
    untick_boulder(boulder_id)
    redirect(session[:current_route])
end

# Creates a new post in the Posts table
# 
# @param [String] :new_post_text, the text content of the post
# @see Model#create_post
post('/posts') do
    text = params[:new_post_text]
    create_post(text)
    redirect(session[:current_route])
end

# Displayes a given post and its post chain if one exists and the comments on the post
# 
# @param [String] :post_id, id of the post to be shown
# @see Model#get_post_chain
# @see Model#get_comments
get('/post/show/:post_id') do
    post_id = params[:post_id]
    post_chain = get_post_chain(post_id)
    p "post chain is:",post_chain
    comments = get_comments(post_id)
    slim(:"posts/show", locals:{post_chain:post_chain, comments:comments})
end

# Likes a post
# 
# @param [String] :post_id, id of the post to be liked
# @see Model#like_post
post('/like_post/:post_id') do
    post_id = params[:post_id]
    like_post(post_id)
    redirect(session[:current_route])
end

# Unlikes a previously liked post
# 
# @param [String] :post_id, id of the post to remove like from
# @see Model#unlike_post
post('/unlike_post/:post_id') do
    post_id = params[:post_id]
    unlike_post(post_id)
    redirect(session[:current_route])
end

# Creates a post on another post
# 
# @param [String] :commented_on_id, id of the post to comment on
# @param [String] :new_comment_text, text content of the new comment
# @see Model#post_comment
post('/comment/:commented_on_id') do 
    commented_on_id = params[:commented_on_id]
    text = params[:new_comment_text]
    post_comment(text, commented_on_id)
    redirect(session[:current_route])
end

# Displayes the maneging page for admins to remove and edit posts in the Posts table
# 
# @see Model#get_all_posts
get('/manege_posts') do
    if session[:user] != nil && session[:user]["permission"] == "admin"
        posts = get_all_posts()
        slim(:"posts/manege", locals:{posts:posts})
    else
        redirect(session[:last_route_visited])
    end
end

# Updates a previous post with new content
# 
# @param [String] :post_id, id of the post to update
# @param [String] :new_text, the new text content of the post
# @see Model#update_text
post('/posts/update/:post_id') do
    post_id = params[:post_id]
    new_text = params[:new_text]
    update_text(post_id, new_text)
    redirect(session[:current_route])
end

# Deletes a privious post
# 
# @param [String] :pots_id, id of the post to delete
# @see Model#get_poster
# @see Model#delete_post
post('/posts/delete/:post_id') do
    post_id = params[:post_id]
    if session[:user]["permission"] == "admin" || session[:user]["id"] == get_poster(post_id)
        delete_post(post_id)
    end
    redirect(session[:current_route])
end

# Displayes the post edit page which lets a user update theirown old post
# 
# @param [String] :post_id, id of the post to edit
# @see Model#get_post
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
        return db.execute("SELECT Users.* FROM Users INNER JOIN Posts ON Posts.user_id = Users.id WHERE Posts.id = ?", post_id).first
    end
end