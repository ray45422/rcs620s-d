import std.stdio;
import std.string;
import std.conv;
import core.thread;
import serial.device;
import nfc.device.rcs620s;
RCS620S rcs620s;
struct ServiceAttribute{
	this(ubyte attr){
		_attr = attr;
	}
	@property
	ubyte attr(){
		return _attr;
	}
	string toString(){
		if(_attr > 7 && _attr < 24){
			return ServiceAttributeString[_attr];
		}
		return "";
	}
	T opCast(T)()if(isIntegral!T){
		return _attr;
	}
	T opCast(T)()if(isSomeString!T){
		return toString;
	}
	bool opEquals(ServiceAttribute val){
		return val.attr == _attr;
	}
	import std.traits;
	bool opEquals(T)(T val)if(isIntegral!T){
		return _attr == val;
	}
private:
	ubyte _attr;
}
enum ServiceAttributes{
	RANDOM_RW_AUTH      = ServiceAttribute(0b001000),
	RANDOM_RW_NOAUTH    = ServiceAttribute(0b001001),
	RANDOM_R_AUTH       = ServiceAttribute(0b001010),
	RANDOM_R_NOAUTH     = ServiceAttribute(0b001011),
	CYCLIC_RW_AUTH      = ServiceAttribute(0b001100),
	CYCLIC_RW_NOAUTH    = ServiceAttribute(0b001101),
	CYCLIC_R_AUTH       = ServiceAttribute(0b001110),
	CYCLIC_R_NOAUTH     = ServiceAttribute(0b001111),
	PARSE_DIRECT_AUTH   = ServiceAttribute(0b010000),
	PARSE_DIRECT_NOAUTH = ServiceAttribute(0b010001),
	PARSE_CBDE_AUTH     = ServiceAttribute(0b010010),
	PARSE_CBDE_NOAUTH   = ServiceAttribute(0b010011),
	PARSE_DE_AUTH       = ServiceAttribute(0b010100),
	PARSE_DE_NOAUTH     = ServiceAttribute(0b010101),
	PARSE_R_AUTH        = ServiceAttribute(0b010110),
	PARSE_R_NOAUTH      = ServiceAttribute(0b010111),
}
immutable string[] ServiceAttributeString = [
	0b001000: "Random Service Read/Write: Authentication Required",
	0b001001: "Random Service Read/Write: No Authentication Required",
	0b001010: "Random Service Read only : Authentication Required",
	0b001011: "Random Service Read only : No Authentication Required",
	0b001100: "Cyclic Service Read/Write: Authentication Required",
	0b001101: "Cyclic Service Read/Write: No Authentication Required",
	0b001110: "Cyclic Service Read only : No Authentication Required",
	0b001111: "Cyclic Service Read only : No Authentication Required",
	0b010000: "Parse Service  Direct    : Authentication Required",
	0b010001: "Parse Service  Direct    : No Authentication Required",
	0b010010: "Parse Service  CB/DE     : Authentication Required",
	0b010011: "Parse Service  CB/DE     : Authentication Required",
	0b010100: "Parse Service  Decrement : Authentication Required",
	0b010101: "Parse Service  Decrement : No Authentication Required",
	0b010110: "Parse Service  Read only : Authentication Required",
	0b010111: "Parse Service  Read only : Authentication Required",
];
void print(ubyte[] data){
	rcs620s.writeArray(data);
}
void nodePrint(ubyte[][] data){
	foreach(d; data){
		rcs620s.writeArray(d);
	}
}
void polPrint(ubyte[] data){
	data.print;
	if(data.length <= 2){
		"not enough length".writeln;
		return;
	}
	if(data[0..2] != [0xd5, 0x4b]){
		"not pol rcv".writeln;
		return;
	}
	"tags count:".write;
	data[2].writeln;
	Tag[] tags = data.splitTag;
	foreach(tag; tags){
		tag.write;
		lastTag = tag;
	}
}
ubyte[][] requestService(ubyte[] idm, ubyte[][] nodes){
	ubyte[] data = 0x02 ~ idm;
	ubyte nodeCount = nodes.length.to!ubyte;
	data ~= nodeCount;
	foreach(node; nodes){
		data ~= node;
	}
	auto rcv = rcs620s.cardCommand(data);
	if(rcv[0] != 0x03){
		"not response".writeln;
		return null;
	}
	rcv = rcv[1..$];
	if(rcv[0..8] != idm){
		"wrong tag".writeln;
		return null;
	}
	rcv = rcv[8..$];
	if(rcv[0] != nodeCount){
		"wrong count".writeln;
		return null;
	}
	rcv = rcv[1..$];
	nodes = [];
	while(rcv.length != 0){
		nodes ~= rcv[0..2];
		rcv = rcv[2..$];
	}
	return nodes;
}
ubyte[][] readWithoutEncrypt(ubyte[] idm, ushort[] services, ushort[] blocks){
	ubyte[] data = [0x06];
	data ~= idm;
	ubyte serviceCount = services.length.to!ubyte;
	data ~= serviceCount;
	foreach(serviceN; services){
		ubyte[] service;
		service ~= serviceN & 0xff;
		service ~= (serviceN >> 8) & 0xff;
		data ~= service;
	}
	ubyte blockCount = blocks.length.to!ubyte;
	data ~= blockCount;
	foreach(blockN; blocks){
		ubyte[] block;
		if(blockN > 0xff){
			block ~= 0b10000000;
			block ~= (blockN >> 8) & 0xff;
			block ~= blockN & 0xff;
		}else{
			block ~= 0b10000000;
			block ~= blockN & 0xff;
		}
		data ~= block;
	}
	data.print;
	auto rcv = rcs620s.cardCommand(data);
	if(rcv is null){
		return null;
	}
	if(rcv[0] != 0x07){
		"not response".writeln;
		return null;
	}
	rcv = rcv[1..$];
	if(rcv[0..8] != idm){
		"wrong tag".writeln;
		return null;
	}
	rcv = rcv[8..$];
	if(rcv[0..2] != [0x00, 0x00]){
		"error code:".write;
		rcv[0..2].print;
		return null;
	}
	rcv = rcv[2..$];
	ubyte[][] blockData = [];
	ubyte len = rcv[0];
	rcv = rcv[1..$];
	for(int i = 0; i < len; ++i){
		blockData ~= rcv[0..16];
		rcv = rcv[16..$];
	}
	return blockData;
}
void balance(){
	rcs620s.polling(0x01, 0x01, 0x03, 0x01).polPrint;
	if(lastTag.reqData != [0x00, 0x03]){
		"balance data not exsist".writeln;
		return;
	}
	ushort[] service = [0x090f];
	ushort[] block = [0x00];
	auto blocks = readWithoutEncrypt(lastTag.idm, service, block);
	if(blocks is null){
		return;
	}
	auto b = blocks[0];
	ubyte console = b[0];
	ubyte process = b[1];
	ushort date = b[4] << 8 | b[5];
	ubyte year = (date >> 9) & 0x7f;
	ubyte month = (date >> 5) & 0x0f;
	ubyte day = date & 0x1f;
	ushort balance = b[11] << 8 | b[10];
	ubyte inLine = b[6];
	ubyte inStation = b[7];
	ubyte outLine = b[8];
	ubyte outStation = b[9];
	writefln("console:%x", console);
	writefln("process:%x", process);
	writefln("%d/%d/%d", year, month, day);
	writefln("in : %x:%x", inLine, inStation);
	writefln("out: %x:%x", outLine, outStation);
	writefln("%d円", balance);
}
struct Tag{
	ubyte[] idm;
	ubyte[] ppm;
	ubyte[] reqData;
	this(ubyte[] data){
		idm = data[0..8];
		ppm = data[8..16];
		reqData = data[16..$];
	}
	void write(){
		"idm:".write;
		print(idm);
		"ppm:".write;
		print(ppm);
		"reqData:".write;
		print(reqData);
	}
}
Tag[] splitTag(ubyte[] data){
	Tag[] tags;
	auto count = data[2];
	data = data[3..$];
	for(int i = 0; i < count; i++){
		data.print;
		auto len = data[1];
		tags ~= Tag(data[3..len+1]);
		data = data[(len+1)..$];
	}
	return tags;
}
Tag lastTag;
void main()
{
	rcs620s = new RCS620S(new SerialPort("/dev/ttyUSB0",dur!"msecs"(100),dur!"msecs"(100)));
	rcs620s.polling(1, 1, 0xffff, 1).polPrint;
	if(lastTag.reqData == [0x00, 0x03]){
		balance();
	}
	bool running = true;
	while(running){
		"command> ".write;
		auto command = readln.chomp;
		ubyte[] data;
		switch(command){
			case "firm":
				rcs620s.getFirmwareVersion.print;
				break;
			case "status":
				rcs620s.getStatus.print;
				break;
			case "reset":
				rcs620s.reset.print;
				break;
			case "rfon":
				rcs620s.rfOn.print;
				break;
			case "rfoff":
				data = [0xd4, 0x32, 0x01, 0x00];
				rcs620s.rfOff;
				break;
			case "retry":
				//data = [0xd4, 0x32, 0x05, 0xff, 0x00, 0x00];
				//send(data).print;
				break;
			case "pol":
				"count:".write;
				ubyte count = readln.chomp.to!ubyte;
				"speed:".write;
				ubyte speed = readln.chomp.to!ubyte;
				"sysCode:".write;
				uint systemCode = readln.chomp.to!uint(16);
				"reqCode:".write;
				ubyte requestCode = readln.chomp.to!ubyte;
				rcs620s.polling(count, speed, systemCode, requestCode).polPrint;
				break;
			case "scanSrv":
				ubyte[][] nodes;
				for(uint i = 0; i < 0b1111111111; ++i){
					for(uint attr = 8; attr < 24; ++attr){
						if(attr % 2 == 0){
							continue;
						}
						ubyte[] d;
						d ~= (((i << 6) & 0xff) | attr).to!ubyte;
						d ~= ((i >> 2) & 0xff).to!ubyte;
						nodes ~= d;
					}
					auto rcv = requestService(lastTag.idm, nodes);
					foreach(j, keyVer; rcv){
						if(keyVer == [0xff, 0xff]){
							continue;
						}
						auto srvAttr = ServiceAttribute(nodes[j][0] & 0b111111);
						"[node:".write;
						writef("[%02x, %02x]", nodes[j][1], nodes[j][0]);
						", serviceCode:".write;
						i.write;
						", ".write;
						srvAttr.write;
						", keyVer:".write;
						writef("[%02x, %02x]", keyVer[0], keyVer[1]);
						"]".writeln;
					}
					nodes = [];
				}
				break;
			case "reqSrv":
				"node(n < 32):".write;
				ubyte count = readln.chomp.to!ubyte;
				ubyte[][] nodes;
				for(int i = 0; i < count; i++){
					"node".write;
					(i+1).write;
					":".write;
					uint node = readln.chomp.to!uint(16);
					data ~= (node >> 8) & 0xff;
					data ~= node & 0xff;
					nodes ~= data;
					data = [];
				}
				requestService(lastTag.idm, nodes).nodePrint;
				break;
			case "reqSys":
				data ~= 0x0c;
				data ~= lastTag.idm;
				rcs620s.cardCommand(data).print;
				break;
			case "reqRes":
				data ~= 0x04;
				data ~= lastTag.idm;
				rcs620s.cardCommand(data).print;
				break;
			case "read":
				ushort[] services;
				"service count:".write;
				ubyte serviceCount = readln.chomp.to!ubyte;
				data ~= serviceCount;
				for(int i = 0; i < serviceCount; i++){
					"service".write;
					(i+1).write;
					":".write;
					ushort serviceN = readln.chomp.to!ushort(16);
					services ~= serviceN;
				}
				ushort[] blocks;
				"block count:".write;
				ubyte blockCount = readln.chomp.to!ubyte;
				data ~= blockCount;
				for(int i = 0; i < blockCount; i++){
					"block".write;
					(i+1).write;
					":".write;
					blocks ~= readln.chomp.to!ushort(16);
				}
				auto blockData = readWithoutEncrypt(lastTag.idm, services, blocks);
				if(lastTag.reqData == [0x00, 0x03]){
					auto b = blockData[0];
					ubyte console = b[0];
					ubyte process = b[1];
					ushort date = b[4] << 8 | b[5];
					ubyte year = (date >> 9) & 0x7f;
					ubyte month = (date >> 5) & 0x0f;
					ubyte day = date & 0x1f;
					ushort balance = b[11] << 8 | b[10];
					ubyte inLine = b[6];
					ubyte inStation = b[7];
					ubyte outLine = b[8];
					ubyte outStation = b[9];
					writefln("console:%x", console);
					writefln("process:%x", process);
					writefln("%d/%d/%d", year, month, day);
					writefln("in : %x:%x", inLine, inStation);
					writefln("out: %x:%x", outLine, outStation);
					writefln("%d円", balance);
					blockData.nodePrint;
				}else{
					blockData.nodePrint;
				}
				break;
			case "balanceloop":
				while(true){
					balance();
					if(lastTag.reqData != [0x00, 0x03]){
						break;
					}
					import core.thread;
					Thread.sleep(dur!"msecs"(100));
				}
				break;
			case "balance":
				balance();
				break;
			case "com":
				"data> ".write;
				string[] tmp = readln.chomp.split(' ');
				foreach(string s; tmp){
					data ~= s.to!int(16).to!ubyte;
				}
				rcs620s.cardCommand(data).print;
				break;
			/*case "send":
				"data> ".write;
				string[] tmp = readln.chomp.split(' ');
				foreach(string s; tmp){
					data ~= s.to!int(16).to!ubyte;
				}
				data.print;
				send(data).print;
				break;*/
			case "exit":
			case "quit":
			case "e":
			case "q":
				running = false;
				break;
			default:
				"no command".writeln;
				break;
		}
	}

	rcs620s.close();
}
