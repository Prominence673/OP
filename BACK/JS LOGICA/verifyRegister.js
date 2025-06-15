const passwordInput = document.getElementById("password");
    const showPassword = document.getElementById("showpassword");
    const confirmInput = document.getElementById("confirm");
    const minLength = document.getElementById("min-length");
    const lowercase = document.getElementById("lowercase");
    const uppercase = document.getElementById("uppercase");
    const number = document.getElementById("number");
    const special = document.getElementById("special");
    const specialRegex = /[@#$^&+=.!?\-_*]/;
    const form = document.getElementById("register"); 
    const passwordRules = document.getElementById("password-rules");

    showPassword.addEventListener("change", () => {
      const type = showPassword.checked ? "text" : "password";
      passwordInput.type = type;
      confirmInput.type = type;
    });

    passwordInput.addEventListener("input", () => {
      const value = passwordInput.value;
      toggleValid(minLength, value.length >= 8);
      toggleValid(lowercase, /[a-z]/.test(value));
      toggleValid(uppercase, /[A-Z]/.test(value));
      toggleValid(number, /\d/.test(value));
      toggleValid(special, specialRegex.test(value));
    });

    function toggleValid(element, condition) {
      element.style.color = condition ? "green" : "red";
    }

    form.addEventListener("submit", function (e) {
      const pwd = passwordInput.value;
      if (
        pwd.length < 8 ||
        !/[a-z]/.test(pwd) ||
        !/[A-Z]/.test(pwd) ||
        !/\d/.test(pwd) ||
        !specialRegex.test(pwd)
      ) {
        e.preventDefault();
      }
    });

    passwordInput.addEventListener("focus", () => {
      passwordRules.classList.add("active");
    });

    passwordInput.addEventListener("blur", () => {
      setTimeout(() => {
        passwordRules.classList.remove("active");
      }, 200);
    });
    