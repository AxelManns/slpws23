const log_in_button = document.getElementById("log_in_button")
const log_in_form_container = document.getElementById("log_in_form_container")

function toggleLogInForm() {
    log_in_form_container.classList.toggle("log_in_active")
    console.log(log_in_form)
}
if (log_in_button != null) {
    log_in_button.addEventListener("click", toggleLogInForm)
}
// function toggleBoulderForms() {
//     document.getElementById("establish_boulder_form").classList.toggle("hide")
//     document.getElementById("tick_boulder_form").classList.toggle("hide")
// }
// document.getElementsByClassName("first_accent_check")[0].addEventListener("click", toggleBoulderForms)

// const tab_elements = ["posts_tab_profile", "boulders_tab_profile"
const posts_tab = document.getElementById("posts_tab_profile")
const boulders_tab = document.getElementById("boulders_tab_profile")

function toggleProfileContent_posts() {
    // console.log(trigger_element.classList, trigger_element, document.getElementById(trigger_element).classList.contains("not_shown"))
    if (posts_tab.classList.contains("not_shown")) {
        document.getElementById("posts_tab_profile").classList.toggle("not_shown")
        document.getElementById("boulders_tab_profile").classList.toggle("not_shown")
        document.getElementById("profile_boulders").classList.toggle("not_displayed")
        document.getElementById("profile_posts").classList.toggle("not_displayed")
    }
}
function toggleProfileContent_boulders() {
    // console.log(trigger_element.classList, trigger_element, document.getElementById(trigger_element).classList.contains("not_shown"))
    if (boulders_tab.classList.contains("not_shown")) {
        document.getElementById("posts_tab_profile").classList.toggle("not_shown")
        document.getElementById("boulders_tab_profile").classList.toggle("not_shown")
        document.getElementById("profile_boulders").classList.toggle("not_displayed")
        document.getElementById("profile_posts").classList.toggle("not_displayed")
    }
}
if (posts_tab != null && boulders_tab != null) {
    console.log(document.getElementsByClassName("not_shown")[0])
    posts_tab.addEventListener("click", toggleProfileContent_posts)
    boulders_tab.addEventListener("click", toggleProfileContent_boulders)
}
// document.getElementsByClassName("tab")[0].addEventListener("click", toggleProfileContent("boulders_tab_profile"))

const contract_mark = document.getElementById("contract_mark")
function toggleCreatPostWindow() {
    document.getElementById("create_post_container").classList.toggle("retracted")
    console.log(document.getElementById("create_post_container").classList)
}

// console.log(document.getElementsByClassName("not_shown")[0])
if (contract_mark != null) {
    contract_mark.addEventListener("click", toggleCreatPostWindow)
}
if (document.getElementsByClassName("profile_pic_button")[0] != null) {
    document.getElementsByClassName("profile_pic_button").onclick = function () {
        location.href = "www.yoursite.com";
    };
}
