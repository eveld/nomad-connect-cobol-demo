```
# Run the app...
# The app now listens on port 8080 on localhost.
# In different terminals run:
make nginx
make nomad
make consul
make deploy

# Get current balance...
curl http://localhost:8080/accounts/x

# Deposit cash...
curl -X POST -d '{"amount": 300}' http://localhost:8080/accounts/x/deposit

# Withdraw cash...
curl -X POST -d '{"amount": 300}' http://localhost:8080/accounts/x/withdraw
```
