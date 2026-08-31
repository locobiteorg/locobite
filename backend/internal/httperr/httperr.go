package httperr

import (
	"encoding/json"
	"net/http"
)

type Body struct {
	Error string `json:"error"`
	Code  string `json:"code"`
}

func Write(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(Body{Error: message, Code: code})
}

func JSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
