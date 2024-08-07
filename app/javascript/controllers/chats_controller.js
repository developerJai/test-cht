import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("chats controller connected")

    // For right/left swipe on message
    this.touchStartX = 0;
    this.touchStartY = 0;
    this.touchEndX = 0;
    this.touchEndY = 0;
    this.originalX = this.element.offsetLeft;
    this.originalY = this.element.offsetTop;

    document.addEventListener('click', function(e){
      if (document.getElementById('chat-modal').contains(e.target)){
        // Clicked in box
      } else if(e.target.getAttribute("id") != "good-link"){
        // Clicked outside the box
        let modal = document.getElementById("chat-modal")
        modal.classList.add("hidden")
      }
    });

    this.interval = setInterval(() => {
        this.loadMessages();
    }, 3000);
  }

  disconnect() {
      // Clear the interval when the controller is disconnected
      clearInterval(this.interval);
  }

  openModal(){
    let modal = document.getElementById("chat-modal")
    if(modal.classList.contains("hidden")){
      modal.classList.remove("hidden")
      this.checkFunction()
    }else{
      modal.classList.add("hidden")
    }
    
  }

  openRemoved(){
    let removedBox = document.getElementById("removed-text")
    if (removedBox.classList.contains("hidden")) {
      removedBox.classList.remove("hidden")
    } else {
      removedBox.classList.add("hidden")
    }
  }

  closeModal(){
    let modal = document.getElementById("chat-modal")
    modal.classList.add("hidden")
  }

  sendMessage(){
    const msgBox = document.getElementById("text-message")
    const msgValue = msgBox.value

    let msgBtn = document.getElementById('send-message')

    msgBtn.classList.add("hidden")
  
    if(msgValue.trim() != ""){
      const encryptedMsg = btoa(msgValue)

      fetch(`/dash/msg`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({ 'encrypted_data': encryptedMsg, reply_to_id: document.getElementById("reply-to-id").value.trim() }),
        dataType: "json",
        credentials: 'same-origin'
      }).then(response => response.json())
        .then(result => {
          msgBtn.classList.remove("hidden")
          msgBox.value = ""
          this.removeReply()
          if(result.code == 200){
            this.checkFunction()
          }
      }).catch(error => {
        console.error('Error fetching data:', error);
       msgBtn.classList.remove("hidden")
      });
    } else {
      msgBtn.classList.remove("hidden")
    }
  }

  scrollMsgsBtm(){
    // var elem = document.getElementById('message-container');
    // elem.scrollTop = elem.scrollHeight;

    const msgBox = document.getElementById("text-message")
    msgBox.focus()
  }

  checkFunction() {
    let modal = document.getElementById("chat-modal")
    // Check if the div does not have the hidden class
    if (!modal.classList.contains('hidden')) {
        // Execute your desired functionality here
        // Add your function call or logic here
        const msgFrame = document.getElementById("messages_list");
        msgFrame.src = '/dash';
        msgFrame.reload();
        this.scrollMsgsBtm()
    }
  }

  loadMessages(){
    let indicator = document.getElementById("new-message-indicator")
    if(indicator.value == "true") {
      indicator.value = "false"
      const msgFrame = document.getElementById("messages_list");
      msgFrame.src = '/dash';
      msgFrame.reload();
      this.scrollMsgsBtm()
    }
  }

  messageTimestamp(){
    const msgTimeDivId = event.currentTarget.getAttribute("attr-msg")
    const msgTimeDiv = document.getElementById(msgTimeDivId)
    if (msgTimeDiv.classList.contains("hidden")) {
      msgTimeDiv.classList.remove("hidden")
    } else {
      msgTimeDiv.classList.add("hidden")
    }
  }

  addReply(){
    const replyMsgId= event.currentTarget.getAttribute("attr-msg-id")
    const replyMsgContent = document.getElementById('msg-content-'+replyMsgId).innerText
    document.getElementById("reply-to-id").value = replyMsgId
    document.getElementById("reply-to").innerText = "Reply to: " +  (replyMsgContent.length > 60 ? replyMsgContent.substring(0,60)+"..." : replyMsgContent)
    document.getElementById('reply-msg-box').classList.remove("hidden")
    this.scrollMsgsBtm()
  }

  removeReply(){
    document.getElementById('reply-msg-box').classList.add("hidden")
    document.getElementById('reply-to-id').value = ""
    document.getElementById('reply-to').value = ""
    this.scrollMsgsBtm()
  }

  clearImg(){
    var output = document.getElementById('selected-image');
    output.src = ""
    document.getElementById("file-input").value = ""
    document.getElementById("img-btns").classList.add("hidden")
  }

  filePreview(){
    var output = document.getElementById('selected-image');
    output.src = URL.createObjectURL(event.target.files[0]);
    console.log(document.getElementById("img-btns").classList)
    document.getElementById("img-btns").classList.remove("hidden")
    output.onload = function() {
      URL.revokeObjectURL(output.src) // free memory
    }
  }

  sendImage(){
    document.getElementById("send-img").innerText = "Sending wait please..."
  }

  openImageModal(){
    const modalId = event.currentTarget.getAttribute("data-modal-target")
    console.log(modalId)
    document.getElementById(modalId).classList.remove("hidden")
  }

  closeImageModal(){
    const modalId = event.currentTarget.getAttribute("attr-modal")
    document.getElementById(modalId).classList.add("hidden")
  }
}
