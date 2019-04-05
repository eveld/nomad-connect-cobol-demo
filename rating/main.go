package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
)

var address string
var target string

type Payload struct {
	Amount int `json:"amount"`
}

type Balance struct {
	Account string `json:"account"`
	Balance string `json:"balance"`
}

func main() {
	address = os.Args[1]
	target = os.Args[2]

	r := mux.NewRouter()
	r.HandleFunc("/upload", UploadHandler).Methods("POST")
	r.HandleFunc("/healthz", HealthHandler).Methods("GET")

	log.Println("Starting server...")
	log.Fatal(http.ListenAndServe(address, r))
}

// HealthHandler responds to health checks.
func HealthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode("ok")
}

// UploadHandler accepts an image and determines it's worth, then deposits that amount.
func UploadHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	r.ParseMultipartForm(32 << 20)

	file, handler, err := r.FormFile("image")
	if err != nil {
		fmt.Println(err)
		return
	}
	defer file.Close()

	account := r.FormValue("account")
	payload := Payload{
		Amount: int(handler.Size),
	}

	content, err := json.Marshal(payload)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	client := &http.Client{
		Timeout: time.Second * 10,
	}

	url := fmt.Sprintf(`http://%s/accounts/%s/deposit`, target, account)
	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(content))
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if resp.StatusCode > 200 {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var response Balance
	json.NewDecoder(resp.Body).Decode(&response)

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}
