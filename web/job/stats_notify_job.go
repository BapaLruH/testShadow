package job

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"time"
	"xray-ui/logger"
	"xray-ui/util/common"
	"xray-ui/web/service"
)

var SSHLoginUser int

type LoginStatus byte

const (
	LoginSuccess LoginStatus = 1
	LoginFail    LoginStatus = 0
)

type StatsNotifyJob struct {
	enable          bool
	telegramService service.TelegramService
	xrayService     service.XrayService
	inboundService  service.InboundService
	settingService  service.SettingService
}

func NewStatsNotifyJob() *StatsNotifyJob {
	return new(StatsNotifyJob)
}

// Here run is a interface method of Job interface
func (j *StatsNotifyJob) Run() {
	if !j.xrayService.IsXrayRunning() {
		return
	}
	var info string
	info = j.GetsystemStatus()
	j.telegramService.SendMsgToTgbot(info)
}

func (j *StatsNotifyJob) UserLoginNotify(username string, ip string, time string, status LoginStatus) {
	if username == "" || ip == "" || time == "" {
		logger.Warning("UserLoginNotify failed, invalid info")
		return
	}
	var msg string
	//get hostname
	name, err := os.Hostname()
	if err != nil {
		fmt.Println("get hostname error: ", err)
		return
	}
	if status == LoginSuccess {
		msg = fmt.Sprintf("Panel login success reminder\nHost name: %s\r\n", name)
	} else if status == LoginFail {
		msg = fmt.Sprintf("Reminder of panel login failure\nHost name: %s\r\n", name)
	}
	msg += fmt.Sprintf("Time: %s\r\n", time)
	msg += fmt.Sprintf("Username: %s\r\n", username)
	msg += fmt.Sprintf("IP: %s\r\n", ip)
	j.telegramService.SendMsgToTgbot(msg)
}

func (j *StatsNotifyJob) SSHStatusLoginNotify(xuiStartTime string) {
	getSSHUserNumber, error := exec.Command("bash", "-c", "who | awk  '{print $1}' | wc -l").Output()
	if error != nil {
		fmt.Println("getSSHUserNumber error: ", error)
		return
	}
	var numberInt int
	numberInt, error = strconv.Atoi(common.ByteToString(getSSHUserNumber))
	if error != nil {
		return
	}
	if numberInt > SSHLoginUser {
		var SSHLoginInfo string
		SSHLoginUser = numberInt
		//hostname
		name, err := os.Hostname()
		if err != nil {
			fmt.Println("get hostname error: ", err)
			return
		}
		//Time compare,need if xray-ui got restart while ssh already exist users
		SSHLoginTime, error := exec.Command("bash", "-c", "who | awk  '{print $3,$4}' | tail -n 1 ").Output()
		if error != nil {
			fmt.Println("getLoginTime error: ", error.Error())
			return
		}
		/*
			//TODO:time compare if xray-ui get restart and there exist logging users
			XUIRunTime, error := exec.Command("bash", "-c", " systemctl status xray-ui | grep Active| tail -n 1 | awk '{print $6,$7}' ").Output()
			if error != nil {
				fmt.Println("getXUIRunTime error:", error.Error())
				return
			}
		*/
		var SSHLoginTimeStr string
		SSHLoginTimeStr = common.ByteToString(SSHLoginTime)
		t1, err := time.Parse("2006-01-02 15:04:05", SSHLoginTimeStr)
		t2, err := time.Parse("2006-01-02 15:04:05", xuiStartTime)
		if t1.Before(t2) || err != nil {
			fmt.Printf("SSHLogin[%s] early than XRAY-UI start[%s]\r\n", SSHLoginTimeStr, xuiStartTime)
		}

		SSHLoginUserName, error := exec.Command("bash", "-c", "who | awk  '{print $1}'| tail -n 1").Output()
		if error != nil {
			fmt.Println("getSSHLoginUserName error: ", error.Error())
			return
		}

		SSHLoginIpAddr, error := exec.Command("bash", "-c", "who | awk -F [\\(\\)] 'NR==1 {print $2}'").Output()
		if error != nil {
			fmt.Println("getSSHLoginIpAddr error: ", error)
			return
		}

		SSHLoginInfo = fmt.Sprintf("New user login reminder:\r\n")
		SSHLoginInfo += fmt.Sprintf("Host name:%s\r\n", name)
		SSHLoginInfo += fmt.Sprintf("SSHLoginUsername:%s", SSHLoginUserName)
		SSHLoginInfo += fmt.Sprintf("SSHLoginTime:%s", SSHLoginTime)
		SSHLoginInfo += fmt.Sprintf("SSHLoginIPAddr:%s", SSHLoginIpAddr)
		SSHLoginInfo += fmt.Sprintf("Current number of SSH logged-in users:%s", getSSHUserNumber)
		j.telegramService.SendMsgToTgbot(SSHLoginInfo)
	} else {
		SSHLoginUser = numberInt
	}
}

func (j *StatsNotifyJob) GetsystemStatus() string {
	var info string
	//get hostname
	name, err := os.Hostname()
	if err != nil {
		fmt.Println("get hostname error:", err)
		return ""
	}
	info = fmt.Sprintf("Host name: %s\r\n", name)
	//get ip address
	var ip string
	ip = common.GetMyIpAddr()
	info += fmt.Sprintf("IP address: %s\r\n \r\n", ip)

	//get traffic
	inbouds, err := j.inboundService.GetAllInbounds()
	if err != nil {
		logger.Warning("StatsNotifyJob run failed: ", err)
		return ""
	}
	//NOTE:If there no any sessions here,need to notify here
	//TODO: Push by nodes, automatically convert format
	for _, inbound := range inbouds {
		info += fmt.Sprintf("Node name: %s\nPort: %d\nUplink flow↑: %s\nDownstream flow↓: %s\nTotal flow: %s\r\n", inbound.Remark, inbound.Port, common.FormatTraffic(inbound.Up), common.FormatTraffic(inbound.Down), common.FormatTraffic((inbound.Up + inbound.Down)))
		if inbound.ExpiryTime == 0 {
			info += fmt.Sprintf("Expiration time: indefinitely\r\n \r\n")
		} else {
			info += fmt.Sprintf("Expiration time: %s\r\n \r\n", time.Unix((inbound.ExpiryTime/1000), 0).Format("2006-01-02 15:04:05"))
		}
	}
	return info
}
