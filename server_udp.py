import socket

localIP     = "0.0.0.0"
localPort   = 1024
bufferSize  = 1024

msgFromServer       = "Hello UDP Client!"
bytesToSend         = str.encode(msgFromServer)

# Create a datagram socket
sock = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)

# Bind to address and ip
sock.bind((localIP, localPort))

print("UDP server up and listening on port "+str(localPort))

# Listen for incoming datagrams

while True:
  data, addr = sock.recvfrom(bufferSize)
  print("received message: %s" % data)

  sock.sendto(data, addr)
