package main

import (
	"bytes"
	"context"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	jsoniter "github.com/json-iterator/go"
)

type SNSAlarmEventMessage struct {
	Origin  string                 `json:"Origin"`
	Details map[string]interface{} `json:"Details"`
	Cause   string                 `json:"Cause"`
	Event   string                 `json:"Event"`
}

type CloudWatchAlarmEvent []struct {
	Name     string `json:"AlarmName"`
	OldState string `json:"OldStateValue"`
	NewState string `json:"NewStateValue"`
}

func HandleRequest(ctx context.Context, snsEvent events.SNSEvent) (string, error) {
	webhookURL := os.Getenv("HOOK_URL")
	msgs := make([]string, 0)
	json := jsoniter.ConfigCompatibleWithStandardLibrary
	discord_message := `{
		"username": "홍정민 CloudWatch Monitor",
        "avatar_url": "https://docs.aws.amazon.com/assets/r/images/aws_logo_dark.png",
		"content" : ""
	}`
	msgBody := make(map[string]interface{})
	bodyErr := json.Unmarshal([]byte(discord_message), &msgBody)
	// log.Println(header, msgBody)
	if bodyErr != nil {
		log.Panicln(bodyErr)
	}

	log.Println("Alarm to Webhook..")

	for _, record := range snsEvent.Records {
		originData := new(SNSAlarmEventMessage)
		alarmData := new(CloudWatchAlarmEvent)
		json.Unmarshal([]byte(record.SNS.Message), &originData)
		invokeAlarms := originData.Details["InvokingAlarms"]
		alarms, _ := json.Marshal(invokeAlarms)
		json.Unmarshal([]byte(alarms), &alarmData)
		for _, data := range *alarmData {
			msgs = append(msgs,
				"**Origin** : "+originData.Origin,
				"**AlarmName** : "+data.Name,
				"**OldStateValue** : "+data.OldState,
				"**NewStateValue** : "+data.NewState,
				"**Cause** : "+originData.Cause,
				"**Event** : "+originData.Event)
		}
	}

	msgBody["content"] = strings.Join(msgs, "\n")
	body, msgErr := json.Marshal(msgBody)
	if msgErr != nil {
		log.Fatalln("Failed to parse to JSON")
	}
	payload := bytes.NewBuffer(body)
	// log.Println(payload)
	req, reqErr := http.NewRequest("POST", webhookURL, payload)
	if reqErr != nil {
		log.Panicln("Response Error", reqErr)
	}

	req.Header.Add("Content-Type", "application/json; charset=utf-8")
	req.Header.Add("Content-Length", strconv.Itoa(len(msgs)))
	req.Header.Add("Host", "discord.com")
	req.Header.Add("user-agent", "Mozilla/5.0")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Panicln(err)
	}
	defer resp.Body.Close()

	// Response 체크.
	respBody, err := ioutil.ReadAll(resp.Body)
	return string(respBody), err
}

func main() {
	lambda.Start(HandleRequest)
}
