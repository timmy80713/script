# 取得輸入參數中的服務帳戶 JSON 文件路徑。
service_account_json_file="$1"

# 從服務帳戶 JSON 中提取必要的信息。
client_email=$(cat "${service_account_json_file}" | jq -r '.client_email')
token_uri=$(cat "${service_account_json_file}" | jq -r '.token_uri')
private_key=$(cat "${service_account_json_file}" | jq -r '.private_key')
private_key_id=$(cat "${service_account_json_file}" | jq -r '.private_key_id')

# 定義函數以生成 JWT header。
jwt_header() {
  cat <<EOF | jq -c .
  {
    "alg":"RS256",
    "typ":"JWT",
    "kid":"${private_key_id}"
  }
EOF
}

# 定義函數以生成 JWT payload。
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

# 將 JWT header 和 payload 進行 Base64 encode。
jwt_header_base64_encoded=$(echo -n $(jwt_header) | base64)
jwt_payload_base64_encoded=$(echo -n $(jwt_payload) | base64)

# 組合 JWT 的前兩部分。
jwt_part_1=$(echo -n "${jwt_header_base64_encoded}.${jwt_payload_base64_encoded}" | tr '/+' '_-' | tr -d '=\n')

# 使用私鑰對 JWT 的前兩部分進行簽名，並使用 Base64 encode。
jwt_signature_base64_encoded=$(echo -n "${jwt_part_1}" | openssl dgst -binary -sha256 -sign <(echo -n "${private_key}") | base64)
jwt_part_2=$(echo -n "${jwt_signature_base64_encoded}" | tr '/+' '_-' | tr -d '=\n')

# 組合完整的 JWT
jwt="${jwt_part_1}.${jwt_part_2}"

# 使用生成的 JWT 向 Google OAuth2 服務發出 POST 請求以獲取 access token。
access_token=$(curl --request POST \
  --url https://www.googleapis.com/oauth2/v4/token \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' \
  --data-urlencode "assertion=${jwt}" \
  --silent | jq -r '.access_token')

echo ${access_token} | tr -d '\n' | pbcopy