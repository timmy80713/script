sa_key="$1"

client_email=$(cat "${sa_key}" | jq -r '.client_email')
token_uri=$(cat "${sa_key}" | jq -r '.token_uri')
private_key=$(cat "${sa_key}" | jq -r '.private_key')
private_key_id=$(cat "${sa_key}" | jq -r '.private_key_id')

jwt_header() {
  cat <<EOF | jq -c .
  {
    "alg":"RS256",
    "typ":"JWT",
    "kid":"${private_key_id}"
  }
EOF
}

jwt_payload() {
  cat <<EOF | jq -c .
  {
    "iss": "${client_email}",
    "scope": "https://www.googleapis.com/auth/firebase.messaging",
    "aud": "${token_uri}",
    "exp": $(($(date +%s) + 300)),
    "iat": $(date +%s)
  }
EOF
}

jwt_header_base64_encoded=$(echo -n $(jwt_header) | base64)
jwt_payload_base64_encoded=$(echo -n $(jwt_payload) | base64)

jwt_part_1=$(echo -n "${jwt_header_base64_encoded}.${jwt_payload_base64_encoded}" | tr '/+' '_-' | tr -d '=\n')

jwt_signature_base64_encoded=$(echo -n "${jwt_part_1}" | openssl dgst -binary -sha256 -sign <(echo -n "${private_key}") | base64)
jwt_part_2=$(echo -n "${jwt_signature_base64_encoded}" | tr '/+' '_-' | tr -d '=\n')

jwt="${jwt_part_1}.${jwt_part_2}"

access_token=$(curl --request POST \
  --url https://www.googleapis.com/oauth2/v4/token \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' \
  --data-urlencode "assertion=${jwt}" \
  --silent | jq -r '.access_token')

echo ${access_token} | tr -d '\n' | pbcopy