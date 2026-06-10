@PGT-21

# GET /accounts/{accountNumber} - 200
- Return a valid accounts payload for any {accountNumber}
Example: http://localhost:9080/api/v1/cards/accounts/1234
Sample Response:
{
   "StatusCode" : "xyz0-000",
   "Message" : "Success!",
   "serviceName" : "Get Customer Account List",
   "accounts" : [
      {
         "accountType" : "TLM",
         "extendedAccounType" : "ABC",
         "accountNumber" : "xxxxxxxx",
         "accountTransit" : "xxxxx",
         "accountCentre" : "XYZ",
         "accountStatus" : "Open",
         "accountOpenDate" : "YYYY-MM-DD",
         "accountOwnershipType" : "owner",
         "accountOwnershipRole" : "Primary",
         "displayAccountNumber" : "xxxxxxxx-xxx"
      }
   ]
}

# GET /accounts/404
- Return a 404 error message for account number ‘404’
Sample response:
{  
   "transactionNumber":null,
   "order":null,
   "errorDetails":{  
      "status":"404",
      "message":"Number is not available"
   }
}

# GET /accounts/503
Return a 503 error message for account number ‘503’
Sample response:
{
  "error": {
    "message": "Server Unavailable",
    "errorCode": "503"
  }
}