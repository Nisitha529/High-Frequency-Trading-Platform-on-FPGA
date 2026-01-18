# High-Frequency-Trading-Platform-on-FPGA
This repository contains a high-frequency trading system implemented on an FPGA, designed for low-latency market data processing and order execution. The system is built using a modular approach with several layers of abstraction, from Ethernet packet handling to application level trade processing.

## Overview
The system is structured as a pipeline of processing modules, each responsible for a specific aspect of the trading workflow. The design emphasizes low latency and high throughput, critical for HFT applications. The top-level module integrates Ethernet communication, TCP/IP protocol handling, custom IP core processing, order matching, and risk management.
<img width="1892" height="541" alt="Schematic Layout of the High Frequency Trading Platform" src="https://github.com/Nisitha529/High-Frequency-Trading-Platform-on-FPGA/blob/main/img_dir/Schematic_Layout.png" />

## Module Architecture
### Top Level module (top_hft.v)
- The top module serves as the main integration point for all system components. It connects the Ethernet interface with the TCP/IP stack, custom IP core, order matching engine, and risk management system. The design uses AXI-Stream interfaces for high-speed data transfer between modules, ensuring efficient packet processing throughout the system.

### Ethernet Layer (eth_layer.v)
- This module handles Ethernet frame processing, including preamble detection, source/destination MAC address verification, and Ethernet type filtering. It extracts IPv4 packets from incoming frames and encapsulates outgoing IP packets with appropriate Ethernet headers. The implementation includes buffering mechanisms to handle variable-length packets and maintain flow control.

### IP Layer (ip_layer.v)
- The IP layer processes IPv4 packets, verifying version, header length, and protocol type. It handles packet fragmentation and reassembly while maintaining basic integrity checks. The module interfaces with both the Ethernet layer below and the TCP layer above, providing a clean separation between link-layer and transport-layer processing.

### TCP Layer (tcp_layer.v) and TCP/IP Stack (tcp_ip_stack.v)
- These modules implement a simplified TCP protocol stack capable of connection establishment, data transfer, and connection teardown. The design includes state machines for handling TCP states (CLOSED, SYN_SENT, ESTABLISHED, FIN_WAIT) and manages sequence numbers, acknowledgment numbers, and window sizing. The stack maintains transmit and receive buffers for reliable data transfer.

### Custom IP Core (ip_core.v)
- This module serves as a configurable processing element that can apply transformations to incoming data packets based on control register settings. It implements a simple state machine for packet collection, processing, and transmission, with AXI-Stream interfaces for integration with other system components.

### AXI Stream Interface (axi_stream_if.v)
- A generic AXI-Stream interface module that provides standardized communication between components. It includes parameters for configuring data width, destination fields, user fields, and optional signal inclusion (STRB, KEEP, LAST, DEST, USER, ID). The implementation includes monitoring capabilities for debugging data transfers.

### Order Matcher (order_matcher.v)
- The order matching engine implements a full trading engine with support for various order types (limit, market, stop, trailing stop) and execution strategies (aggressive, passive, iceberg, VWAP). It maintains separate bid and ask order books with depth tracking and implements price-time priority matching. The module generates trade reports when orders are matched and communicates with both the TCP stack and risk management system.

### Risk Manager (risk_manager.v)
- This module enforces risk controls by monitoring position and exposure limits. It tracks accumulated position and exposure values, comparing them against configurable maximum limits. The risk manager approves or rejects trades based on these checks, providing an essential safeguard against excessive risk exposure.

## Integration and Operation
The system operates as a coordinated pipeline where market data enters through the Ethernet interface, progresses through protocol processing, undergoes transformation in the custom IP core, gets processed by the order matching engine, and is finally risk-checked before any orders are executed. The modular design allows for individual component testing and replacement, facilitating both simulation and hardware implementation.

## Testing and Verification
Each module includes basic functionality verification, and the integrated system can be tested using Ethernet packet generators and trading simulators. The AXI-Stream interface provides a standardized method for injecting test data and monitoring outputs throughout the processing pipeline.

This HFT FPGA system represents a complete trading infrastructure optimized for low-latency operation, with all critical components implemented directly in hardware for maximum performance.

