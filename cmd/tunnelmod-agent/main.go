package main

import (
	"bufio"
	"encoding/csv"
	"fmt"
	"net"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

type key struct {
	ID    string
	Proto string
}

type stat struct {
	InBytes    uint64
	OutBytes   uint64
	InPackets  uint64
	OutPackets uint64
}

func add(stats map[key]*stat, id, proto string, inB, outB, inP, outP uint64) {
	k := key{id, proto}
	row, ok := stats[k]
	if !ok {
		row = &stat{}
		stats[k] = row
	}
	row.InBytes += inB
	row.OutBytes += outB
	row.InPackets += inP
	row.OutPackets += outP
}

func collectIptables(stats map[key]*stat) {
	cmd := exec.Command("iptables", "-L", "FORWARD", "-n", "-v", "-x")
	out, err := cmd.Output()
	if err != nil {
		return
	}
	re := regexp.MustCompile(`tunnel-panel:(\d+):(tcp|udp)`)
	scanner := bufio.NewScanner(strings.NewReader(string(out)))
	for scanner.Scan() {
		line := scanner.Text()
		m := re.FindStringSubmatch(line)
		if len(m) != 3 {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		packets, err1 := strconv.ParseUint(fields[0], 10, 64)
		bytes, err2 := strconv.ParseUint(fields[1], 10, 64)
		if err1 != nil || err2 != nil {
			continue
		}
		if strings.Contains(line, "spt:") {
			add(stats, m[1], m[2], 0, bytes, 0, packets)
		} else {
			add(stats, m[1], m[2], bytes, 0, packets, 0)
		}
	}
}

func collectHAProxy(stats map[key]*stat) {
	const sockPath = "/run/tunnel-panel-haproxy.sock"
	conn, err := net.DialTimeout("unix", sockPath, 3*time.Second)
	if err != nil {
		return
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(5 * time.Second))
	_, _ = conn.Write([]byte("show stat\n"))
	reader := csv.NewReader(conn)
	reader.FieldsPerRecord = -1
	headers, err := reader.Read()
	if err != nil {
		return
	}
	if len(headers) > 0 {
		headers[0] = strings.TrimPrefix(headers[0], "# ")
	}
	idx := map[string]int{}
	for i, h := range headers {
		idx[h] = i
	}
	for {
		rec, err := reader.Read()
		if err != nil {
			break
		}
		get := func(name string) string {
			i, ok := idx[name]
			if !ok || i >= len(rec) {
				return ""
			}
			return rec[i]
		}
		px := get("pxname")
		if get("svname") != "FRONTEND" || !strings.HasPrefix(px, "tp_front_") {
			continue
		}
		id := strings.TrimPrefix(px, "tp_front_")
		inB, _ := strconv.ParseUint(get("bin"), 10, 64)
		outB, _ := strconv.ParseUint(get("bout"), 10, 64)
		add(stats, id, "tcp", inB, outB, 0, 0)
	}
}

func trafficStats() int {
	stats := map[key]*stat{}
	collectIptables(stats)
	collectHAProxy(stats)
	keys := make([]key, 0, len(stats))
	for k := range stats {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		ai, _ := strconv.Atoi(keys[i].ID)
		aj, _ := strconv.Atoi(keys[j].ID)
		if ai == aj {
			return keys[i].Proto < keys[j].Proto
		}
		return ai < aj
	})
	writer := csv.NewWriter(os.Stdout)
	_ = writer.Write([]string{"id", "proto", "in_bytes", "out_bytes", "in_packets", "out_packets"})
	for _, k := range keys {
		s := stats[k]
		_ = writer.Write([]string{k.ID, k.Proto, fmt.Sprint(s.InBytes), fmt.Sprint(s.OutBytes), fmt.Sprint(s.InPackets), fmt.Sprint(s.OutPackets)})
	}
	writer.Flush()
	return 0
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: tunnelmod-agent traffic-stats")
		os.Exit(2)
	}
	switch os.Args[1] {
	case "traffic-stats":
		os.Exit(trafficStats())
	default:
		fmt.Fprintln(os.Stderr, "unknown command")
		os.Exit(2)
	}
}
