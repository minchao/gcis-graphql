# gcis-graphql

[![Build Status](https://travis-ci.com/minchao/gcis-graphql.svg?branch=master)](https://travis-ci.com/minchao/gcis-graphql)

經濟部商工行政資料 GraphQL 查詢服務，基於 AppSync 與 Lambda resolver 實現，目前支援的 GraphQL 查詢請參考 [schema.graphql](./cloudformation/schema.graphql)

## 必要條件

- [AWS](https://aws.amazon.com/)
  - AppSync
  - Lambda
  - CloudFormation
  - AWS CLI
- [Golang](https://golang.org/)

## 使用

### 安裝

使用 `go get` 指令下載本專案到你的 $GOPATH 路徑下

```bash
go get https://github.com/minchao/gcis-graphql
```

切換到專案目錄，並安裝開發工具與依賴套件

```bash
cd $GOPATH/src/github.com/minchao/gcis-graphql
make install
make deps
```

建立 CloudFormation Stack 參數設定檔

```
vi ./config/test.json
```

請參考 [config/dev.json](./config/dev.json)，自行修改參數

```json
[
  {
    "ParameterKey": "ParamENV",
    "ParameterValue": "test"
  }
]
```

設定環境變數

```bash
export CFN_PARAMETER_FILE="./config/test.json"
```

### 部署

設定 AWS CLI 環境變數

```bash
export AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY"
export AWS_SESSION_TOKEN="YOUR_AWS_SESSION_TOKEN"
```

執行部署

```
make deploy
```

部署完成後可透過 `describe` 指令取得 Stack 的詳細狀態

```bash
make describe
```

## 測試

### 查詢公司名稱

```bash
curl -XPOST https://your-gcis-service.appsync-api.ap-northeast-1.amazonaws.com/graphql \
     -H "Content-Type:application/graphql" \
     -H "x-api-key:your-api-key" \
     -d '{ "query": "query { company(id: 84598349) { id name } }" }' | jq
```

```json
{
  "data": {
    "company": {
      "id": "84598349",
      "name": "一零四資訊科技股份有限公司"
    }
  }
}
```
