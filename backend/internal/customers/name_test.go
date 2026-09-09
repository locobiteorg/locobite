package customers

import "testing"

func TestDisplayNameFromIdentifier(t *testing.T) {
	tests := []struct {
		in, want string
	}{
		{"sourav.s@gmail.com", "Sourav S"},
		{"foo@bar.com", "Foo"},
		{"9876543210", "Traveller 3210"},
		{"  jane_doe-test@x.com ", "Jane Doe Test"},
	}
	for _, tt := range tests {
		if got := displayNameFromIdentifier(tt.in); got != tt.want {
			t.Errorf("displayNameFromIdentifier(%q) = %q, want %q", tt.in, got, tt.want)
		}
	}
}
