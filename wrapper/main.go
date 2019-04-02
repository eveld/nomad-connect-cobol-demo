package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"strings"

	"github.com/gorilla/mux"
)

// Payload holds the deposit or withdraw details.
type Payload struct {
	Amount string `json:"amount"`
}

// Balance holds the balance of a certain account.
type Balance struct {
	Account string `json:"account"`
	Balance string `json:"balance"`
}

func main() {
	r := mux.NewRouter()
	r.HandleFunc("/accounts/{account}/deposit", DepositHandler).Methods("POST")
	r.HandleFunc("/accounts/{account}/withdraw", WithdrawHandler).Methods("POST")
	r.HandleFunc("/accounts/{account}", BalanceHandler).Methods("GET")

	log.Println("Starting server...")
	log.Fatal(http.ListenAndServe(":8080", r))
}

// BalanceHandler abuses deposit of 0 to retrieve the current balance of an account.
func BalanceHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	account := vars["account"]

	log.Printf("INFO: retrieving balance for account %s", account)
	balance, err := callBankingApp(account, "deposit", "0")
	if err != nil {
		log.Printf("ERROR: %s", err.Error())
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(err.Error())
		return
	}

	log.Printf("INFO: current balance for account %s is %s", account, balance.Balance)

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(balance)
}

// DepositHandler handles deposits to an account.
func DepositHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	account := vars["account"]

	var payload Payload
	json.NewDecoder(r.Body).Decode(&payload)

	log.Printf("INFO: depositing %s to account %s", payload.Amount, account)
	balance, err := callBankingApp(account, "deposit", payload.Amount)
	if err != nil {
		log.Printf("ERROR: %s", err.Error())
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(err.Error())
		return
	}

	log.Printf("INFO: new balance for account %s is %s", account, balance.Balance)

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(balance)
}

// WithdrawHandler handles withdraws from an account.
func WithdrawHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	account := vars["account"]

	var payload Payload
	json.NewDecoder(r.Body).Decode(&payload)

	log.Printf("INFO: withdrawing %s from account %s", payload.Amount, account)

	balance, err := callBankingApp(account, "withdraw", payload.Amount)
	if err != nil {
		log.Printf("ERROR: %s", err.Error())
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(err.Error())
		return
	}

	log.Printf("INFO: new balance for account %s is %s", account, balance.Balance)

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(balance)
}

func callBankingApp(account string, mutation string, amount string) (*Balance, error) {
	cmd := exec.Command("banking", account, mutation, amount)
	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		// Grab the error from stderr if something went wrong.
		message := strings.TrimSuffix(stderr.String(), "\n")
		return nil, fmt.Errorf(message)
	}

	result := strings.TrimSuffix(out.String(), "\n")
	fields := strings.Split(result, ",")

	// Parse the output.
	balance := Balance{
		Account: fields[0],
		Balance: fields[1],
	}

	return &balance, nil
}
