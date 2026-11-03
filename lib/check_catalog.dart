const checkIntroductions = <String, (String, String)>{
  "tcp": (
    "TCP - Transmission Control Protocol\nTransport layer (OSI layer 4)\nTCP (Transmission Control Protocol) provides a connection-oriented, reliable, ordered byte stream using acknowledgements and retransmissions. TCP checks measure whether a target port accepts a connection and how long it takes.",
    "TCP - 传输控制协议\n传输层（OSI 第 4 层）\nTCP（Transmission Control Protocol，传输控制协议）提供面向连接、可靠且有序的字节流传输，通过确认、重传等机制处理数据丢失。TCP 探测检查目标端口能否建立连接及连接耗时。",
  ),
  "udp": (
    "UDP - User Datagram Protocol\nTransport layer (OSI layer 4)\nUDP (User Datagram Protocol) sends connectionless datagrams without guaranteeing delivery or ordering. It is used by DNS and real-time media applications. UDP checks send a payload and wait for a reply.",
    "UDP - 用户数据报协议\n传输层（OSI 第 4 层）\nUDP（User Datagram Protocol，用户数据报协议）以无连接的数据报方式传输消息，协议本身不保证送达或顺序，常用于 DNS、实时音视频等场景。UDP 探测发送指定数据并等待响应。",
  ),
  "ping": (
    "ICMP - Internet Control Message Protocol\nNetwork layer (OSI layer 3)\nICMP (Internet Control Message Protocol) carries error and control information for IP networks. Ping uses echo requests and replies to measure round-trip latency and loss; firewall policies can affect replies.",
    "ICMP - 互联网控制报文协议\n网络层（OSI 第 3 层）\nICMP（Internet Control Message Protocol，互联网控制报文协议）用于传递 IP 网络的错误和控制信息。Ping 利用其回显请求与应答测量往返延迟和丢包率；是否回应也受防火墙策略影响。",
  ),
  "http": (
    "HTTP / HTTPS - Hypertext Transfer Protocol\nApplication layer (OSI layer 7)\nHTTP (Hypertext Transfer Protocol) exchanges web and API resources through requests and responses. HTTPS protects HTTP with TLS and authenticates the server. These checks examine response status, content, timing and certificates.",
    "HTTP / HTTPS - 超文本传输协议\n应用层（OSI 第 7 层）\nHTTP（Hypertext Transfer Protocol，超文本传输协议）通过请求与响应交换网页、API 等资源。HTTPS 使用 TLS 保护 HTTP 通信并验证服务端身份。此类探测检查响应状态、内容、耗时及证书。",
  ),
  "dns": (
    "DNS - Domain Name System\nApplication layer (OSI layer 7)\nDNS (Domain Name System) is a distributed naming system for records such as IP addresses and mail servers. Traditional queries use UDP or TCP port 53. DNS checks inspect answers and query time.",
    "DNS - 域名系统\n应用层（OSI 第 7 层）\nDNS（Domain Name System，域名系统）是一套分布式命名系统，用于查询域名对应的 IP 地址、邮件服务器等资源记录，传统查询通常使用 UDP 或 TCP 的 53 端口。DNS 探测检查解析结果和查询耗时。",
  ),
  "mtr": (
    "MTR - Route diagnostics\nDiagnostic tool\nMTR combines route tracing and repeated probes to report replies, latency and loss along a path. It is a diagnostic tool, not a separate protocol; router reply limits can affect its output.",
    "MTR - 路由诊断工具\n诊断工具\nMTR 是结合路由追踪与连续 Ping 的网络诊断工具，展示到目标路径上各跳的响应、延迟和丢包情况。它不是独立的通信协议；中间路由器的应答限制可能影响显示结果。",
  ),
  "traceroute": (
    "Traceroute - Route tracing\nDiagnostic tool\nTraceroute infers a route by increasing the IP time-to-live (TTL) and examining replies. It is a diagnostic tool, not a separate protocol, and can use UDP, ICMP or TCP probes.",
    "Traceroute - 路由追踪工具\n诊断工具\nTraceroute 是路由追踪工具，通过逐步增加 IP 报文的生存时间（TTL）并分析返回报文推断路径。它不是独立的通信协议，工具可使用 UDP、ICMP 或 TCP 发送探测。",
  ),
};
