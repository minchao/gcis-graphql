package main

import (
	"github.com/minchao/gcis-graphql/internal/app/handles"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/sbstjn/appsync-resolvers"
)

var (
	r = resolvers.New()
)

func init() {
	_ = r.Add("query.company", handles.HandleCompany)
	_ = r.Add("query.search", handles.HandleSearch)
}

func main() {
	lambda.Start(r.Handle)
}
