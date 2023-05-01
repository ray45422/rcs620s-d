import std.stdio;
import std.string;
import std.conv;
import std.traits;
import std.algorithm.searching;
import core.thread;
import serial.device;
import nfc.device.rcs620s;
import nfc.tag.felica;
import nfc.tag.felica.serviceBlock;
RCS620S rcs620s;
void print(ubyte[] data){
	rcs620s.writeArray(data);
}
void nodePrint(ubyte[][] data){
	foreach(d; data){
		rcs620s.writeArray(d);
	}
}
ubyte[][] requestService(FeliCa tag, ubyte[][] nodes){
	ubyte[] data = 0x02 ~ tag.idm;
	ubyte nodeCount = nodes.length.to!ubyte;
	data ~= nodeCount;
	foreach(node; nodes){
		data ~= node;
	}
	auto rcv = tag.command(data);
	if(rcv.length == 0){
		return null;
	}
	if(rcv[0] != 0x03){
		"not response".writeln;
		return null;
	}
	rcv = rcv[1..$];
	if(rcv[0..8] != tag.idm){
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
ubyte[][] readWithoutEncrypt(FeliCa tag, ushort[] services, ushort[] blocks){
	ubyte[] data = [0x06];
	data ~= tag.idm;
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
	auto rcv = tag.command(data);
	if(rcv is null){
		return null;
	}
	if(rcv[0] != 0x07){
		"not response".writeln;
		return null;
	}
	rcv = rcv[1..$];
	if(rcv[0..8] != tag.idm){
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
	import std.json;
	import std.file;
	auto tags = rcs620s.polling(0x01, 0x01, 0x03, 0x01);
	if(tags.length == 0){
		return;
	}
	auto lastTag = tags[0];
	JSONValue j = ["product": lastTag.product.name];
	if(!lastTag.systemCode.canFind(0x0003)){
		"balance data not exsist".writeln;
		j.object["deposit"] = JSONValue("未対応のカードです");
	} else {
		ushort[] service = [0x090f];
		ushort[] block = [0x00];
		auto blocks = readWithoutEncrypt(lastTag, service, block);
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
		j.object["deposit"] = JSONValue(balance);
	}
	j.toString.writeln;
	auto head = File("./source/head.html");
	"./source/head.html".copy("/tmp/index.html");
	auto html = File("/tmp/index.html", "a");
	html.write(j.toString);
	auto foot = File("./source/foot.html");
	foreach(string line; foot.lines) {
		html.writeln(line);
	}
	html.flush;
	html.close();
	import std.process;
	auto pid = spawnProcess(["xdotool", "key", "--window", "Google Chrome", "F5"]);
	wait(pid);
}
FeliCa lastTag;
void main()
{
	rcs620s = new RCS620S(new SerialPort("/dev/ttyUSB0",dur!"msecs"(100),dur!"msecs"(100)));
	bool running = true;
	FeliCa lastTag = null;
	while(running) {
		import std.json;
		import std.file;
		//Thread.sleep(dur!"msecs"(100));
		auto tags = rcs620s.polling(0x01, 0x01, 0xffff, 0x01);
		if(tags.length == 0){
			continue;
		}
		if(lastTag !is null && lastTag.idm == tags[0].idm) {
			continue;
		}
		lastTag = tags[0];
		JSONValue j = ["product": lastTag.product.name];
		if(lastTag.systemCode.canFind([0x0003], [0x865e])){
			ushort[] service = [0x090f];
			ushort[] block = [0x00];
			auto blocks = readWithoutEncrypt(lastTag, service, block);
			if(blocks is null){
				continue;
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
			string bal = balance.to!string ~ "円";
			j.object["deposit"] = JSONValue(bal);
		} else {
			"balance data not exsist".writeln;
			j.object["deposit"] = JSONValue("未対応のカードです");
		}
		j.toString.writeln;
		auto head = File("./source/head.html");
		"./source/head.html".copy("/tmp/index.html");
		auto html = File("/tmp/index.html", "a");
		html.write(j.toString);
		auto foot = File("./source/foot.html");
		foreach(string line; foot.lines) {
			html.writeln(line);
		}
		html.flush;
		html.close();
		import std.process;
		auto pid = spawnProcess(["xdotool", "key", "--window", "Google Chrome", "F5"]);
		wait(pid);
	}
	rcs620s.close();
}
