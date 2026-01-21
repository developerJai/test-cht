# Configure session timeout
# Default Rails session expires when browser closes
# This extends the session to 30 days
Rails.application.config.session_store :cookie_store, 
  key: '_dmart_session',
  expire_after: 30.days
