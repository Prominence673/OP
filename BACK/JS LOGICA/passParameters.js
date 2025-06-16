class PasswordValidator {
  constructor({
    passwordSelector,
    confirmSelector,
    toggleSelector,
    rulesContainerSelector,
    ruleSelectors,
    formSelector
  }) {
    this.passwordInput = document.querySelector(passwordSelector);
    this.confirmInput = document.querySelector(confirmSelector);
    this.showPasswordCheckbox = document.querySelector(toggleSelector);
    this.passwordRulesContainer = document.querySelector(rulesContainerSelector);
    this.form = document.querySelector(formSelector);
    
    this.rules = {
      minLength: document.querySelector(ruleSelectors.minLength),
      lowercase: document.querySelector(ruleSelectors.lowercase),
      uppercase: document.querySelector(ruleSelectors.uppercase),
      number: document.querySelector(ruleSelectors.number),
      special: document.querySelector(ruleSelectors.special)
    };

    this.specialRegex = /[@#$^&+=.!?\-_*]/;

    this.setupEvents();
  }

  setupEvents() {
  
    this.showPasswordCheckbox?.addEventListener("change", () => {
      const type = this.showPasswordCheckbox.checked ? "text" : "password";
      this.passwordInput.type = type;
      this.confirmInput.type = type;
    });

  
    this.passwordInput.addEventListener("input", () => this.validate());


    this.passwordInput.addEventListener("focus", () => {
      this.passwordRulesContainer?.classList.add("active");
    });

    this.passwordInput.addEventListener("blur", () => {
      setTimeout(() => {
        this.passwordRulesContainer?.classList.remove("active");
      }, 200);
    });

  
    this.form?.addEventListener("submit", (e) => {
      if (!this.isPasswordValid()) {
        e.preventDefault();
      }
    });
  }

  validate() {
    const value = this.passwordInput.value;
    this.toggleValid(this.rules.minLength, value.length >= 8);
    this.toggleValid(this.rules.lowercase, /[a-z]/.test(value));
    this.toggleValid(this.rules.uppercase, /[A-Z]/.test(value));
    this.toggleValid(this.rules.number, /\d/.test(value));
    this.toggleValid(this.rules.special, this.specialRegex.test(value));
  }

  toggleValid(element, condition) {
    if (element) {
      element.style.color = condition ? "green" : "red";
    }
  }

  isPasswordValid() {
    const value = this.passwordInput.value;
    return (
      value.length >= 8 &&
      /[a-z]/.test(value) &&
      /[A-Z]/.test(value) &&
      /\d/.test(value) &&
      this.specialRegex.test(value)
    );
  }
}