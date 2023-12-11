# 取得輸入參數中的服務帳戶 JSON 文件路徑。
service_account_json_file="$1"

# 取得輸入參數中的 HTTP cloud function URL。
http_cloud_function_url="$2"

# 從服務帳戶 JSON 中提取必要的信息。
client_email=$(cat "${service_account_json_file}" | jq -r '.client_email')
private_key=$(cat "${service_account_json_file}" | jq -r '.private_key')

# 定義函數以生成 JWT header。
jwt_header() {
  cat <<EOF | jq -c .
  {
    "alg":"RS256",
    "typ":"JWT"
  }
EOF
}

# 定義函數以生成 JWT payload。
jwt_payload() {
  cat <<EOF | jq -c .
  {
    "target_audience": "${http_cloud_function_url}",
    "iss": "${client_email}",
    "sub": "${client_email}",
    "aud": "https://www.googleapis.com/oauth2/v4/token",
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

# 使用生成的 JWT 向 Google OAuth2 服務發出 POST 請求以獲取 id token。
id_token=$(curl --request POST \
  --url https://www.googleapis.com/oauth2/v4/token \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' \
  --data-urlencode "assertion=${jwt}" \
  --silent | jq -r '.id_token')

echo ${id_token} | tr -d '\n' | pbcopy