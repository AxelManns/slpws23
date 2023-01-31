const log_in_button = document.getElementById("log_in_button")
const log_in_form = document.getElementById("log_in_form")

function toggleLogInForm() {
    log_in_form.classList.toggle("log_in_active")
    console.log(log_in_form)
}

console.log("this happens")
log_in_button.addEventListener("click", toggleLogInForm)