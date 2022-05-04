package main

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/joho/godotenv"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

func HandleRequest(ctx context.Context, snsEvent events.SNSEvent) (int, error) {
	envErr := godotenv.Load()
	if envErr != nil {
		log.Fatalln("Failed to load .env file")
	}

	webhookURL := os.Getenv("HOOK_URL")
	msgs := make([]string, 0)
	// reqBody := make(map[string]interface{})

	discord_message := `
	{
		'username': '홍정민 CloudWatch Monitor',
        'avatar_url': 'https://docs.aws.amazon.com/assets/r/images/aws_logo_dark.png',
		'content' : ""
	}
	`
	headerTxt := `
	{
		'Content-Type': 'application/json; charset=utf-8',
		'Content-Length': 0,
        'Host': 'discord.com',
        'user-agent': 'Mozilla/5.0'
	}
	`
	var header map[string]interface{}
	var msgBody map[string]interface{}
	json.Unmarshal([]byte(headerTxt), &header)
	json.Unmarshal([]byte(discord_message), &msgBody)

	log.Println("Alarm to Webhook...")

	for _, record := range snsEvent.Records {
		snsRecord := record.SNS
		log.Printf("[%s %s] Message = %s \n", record.EventSource, snsRecord.Timestamp, snsRecord.Message)
		msgs = append(msgs, snsRecord.Message)
	}
	header["Content-Length"] = len(msgs)
	msgBody["content"] = strings.Join(msgs, "\n")
	body, msgErr := json.Marshal(msgBody)
	if msgErr != nil {
		log.Fatalln("Failed to parse to JSON")
	}
	response, respErr := http.Post(webhookURL, "application/json; charset=utf-8", bytes.NewBuffer(body))

	return response.StatusCode, respErr
}

func main() {
	lambda.Start(HandleRequest)
}
