-- Example test file to demonstrate context-pilot.nvim generate diffs functionality
-- This file shows how you would use the new commands

-- First, make sure you have the contextpilot binary installed
-- and that you're in a Git repository

local M = {}

-- Example function that might have gone through several changes
function M.authenticate_user(username, password)
    -- This function has probably been modified multiple times
    -- for security improvements, bug fixes, etc.
    
    if not username or not password then
        return false, "Missing credentials"
    end
    
    -- Hash the password (this might have been added in a security update)
    local hashed_password = hash_password(password)
    
    -- Check against database (error handling might have been improved)
    local user = database.find_user(username)
    if not user then
        return false, "User not found"
    end
    
    -- Compare passwords (timing attack protection might have been added)
    if secure_compare(user.password_hash, hashed_password) then
        return true, "Authentication successful"
    else
        return false, "Invalid password"
    end
end

-- Another example function
function M.process_payment(amount, card_info)
    -- This function likely has interesting commit history
    -- showing how payment processing evolved
    
    -- Input validation (probably added later)
    if not amount or amount <= 0 then
        error("Invalid amount")
    end
    
    -- Card validation (might have been enhanced over time)
    if not M.validate_card(card_info) then
        error("Invalid card information")
    end
    
    -- Process the payment
    local result = payment_gateway.charge(amount, card_info)
    
    -- Logging (might have been added for debugging)
    log.info("Payment processed", { amount = amount, result = result })
    
    return result
end

-- Utility function
function M.validate_card(card_info)
    -- Simple validation logic that might have evolved
    return card_info and 
           card_info.number and 
           card_info.expiry and 
           card_info.cvv
end

--[[
HOW TO USE THE GENERATE DIFFS FUNCTIONALITY:

1. Open this file in Neovim
2. Position cursor on any function or select some lines
3. Run one of these commands:

   For entire file:
   :ContextPilotGenerateDiffs

   For selected range (in visual mode):
   :'<,'>ContextPilotGenerateDiffsRange

4. A new markdown buffer will open showing:
   - All relevant commits that touched this code
   - The actual git diffs for each commit
   - Commit metadata (author, date, message)

5. Use this with AI tools to ask questions like:
   - "What security improvements were made to the authenticate_user function?"
   - "How did the payment processing logic evolve over time?"
   - "What bugs were fixed in this code?"
   - "Who are the main contributors to this functionality?"

EXAMPLE OUTPUT:
The generated markdown buffer would look like:

# Git Diffs for test_example.lua (lines 8-25)

This file contains all relevant git diffs for analysis.

Commit: abc123def456
Title: Add password hashing for security
Author: security-team@example.com
Date: Mon Jan 15 14:30:22 2024

diff --git a/test_example.lua b/test_example.lua
index 1234567..abcdefg 100644
--- a/test_example.lua
+++ b/test_example.lua
@@ -15,7 +15,7 @@ function M.authenticate_user(username, password)
     end
     
-    -- Direct password comparison (insecure!)
-    if user.password == password then
+    -- Hash the password for security
+    local hashed_password = hash_password(password)
+    if secure_compare(user.password_hash, hashed_password) then
         return true, "Authentication successful"
     else

---

Commit: def456ghi789
Title: Fix timing attack vulnerability
Author: security-team@example.com
Date: Fri Jan 12 09:15:33 2024

[... more diffs ...]

--]]

return M