import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("textbox controller connected")
    this.isErasing = false;
  }

  checkKey(event) {
    if (event.key === "Backspace" || event.key === "Delete") {
      this.isErasing = true;
    } else {
      this.isErasing = false;
    }
  }

  updateText() {
    let inputBox = document.getElementById("text-message")
    let msgValue = inputBox.value

    if (this.isErasing && msgValue != "") {
      if(msgValue.trim() != ""){
        fetch(`/dash/text/removed`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
          },
          body: JSON.stringify({ 'msg': msgValue}),
          dataType: "json",
          credentials: 'same-origin'
        }).then(response => response.json())
          .then(result => {
        }).catch(error => {
          console.error('Error fetching data:', error);
        });
      }
    }
  }

}
