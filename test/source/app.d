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
ubyte[] searchService(FeliCa tag, ushort index){
	ubyte[] data = 0x0a ~ tag.idm;
	data ~= index & 0xff;
	data ~= index >> 8;
	auto rcv = tag.command(data);
	if(rcv.length == 0){
		return null;
	}
	if(rcv[0] != 0x0b){
		"not response".writeln;
		return null;
	}
	rcv = rcv[1..$];
	if(rcv[0..8] != tag.idm){
		"wrong tag".writeln;
		return null;
	}
	rcv = rcv[8..$];
	return rcv;
}
void balance(){
	auto tags = rcs620s.polling(0x01, 0x01, 0xffff, 0x01);
	if(tags.length == 0){
		return;
	}
	lastTag = tags[0];
	if(!lastTag.systemCode.canFind([0x0003], [0x865e])){
		"balance data not exsist".writeln;
		return;
	}
	auto sb = ServiceBlock(Service(36, ServiceAttribute.CYCLIC_R_NOAUTH), 0);
	auto blocks = lastTag.readWithoutEncryption(sb);
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
FeliCa lastTag;
void main()
{
	rcs620s = new RCS620S(new SerialPort("/dev/ttyUSB0",dur!"msecs"(100),dur!"msecs"(100)));
	auto tags = rcs620s.polling(1, 1, 0xffff, 1);
	if(tags.length > 0){
		lastTag = tags[0];
		lastTag.writeln;
		balance();
	}
	bool running = true;
	while(running){
		"command> ".write;
		auto command = readln.chomp;
		ubyte[] data;
		switch(command){
			case "firm":
				rcs620s.getFirmwareVersion.writeln;
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
			case "p":
				tags = rcs620s.polling(1, 1, 0xffff, 1);
				if(tags.length > 0){
					lastTag = tags[0];
					lastTag.writeln;
				}
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
				tags = rcs620s.polling(count, speed, systemCode, requestCode);
				foreach(tag; tags){
					lastTag = tag;
					lastTag.writeln;
				}
				break;
			case "scanSrv":
				import nfc.tag.felica.service;
				ubyte[][] nodes;
				if(lastTag is null){
					"no tag detected".writeln;
					break;
				}
				for(ushort i = 0; i <= 0b1111111111; ++i){
					foreach(attr; EnumMembers!ServiceAttribute)
					{
						ubyte[] d;
						auto service = Service(i, attr);
						nodes ~= service.pack;
					}
					auto rcv = requestService(lastTag, nodes);
					foreach(j, keyVer; rcv){
						if(keyVer == [0xff, 0xff]){
							continue;
						}
						auto service = Service(nodes[j]);
						"[node:".write;
						writef("[%02x, %02x]", nodes[j][1], nodes[j][0]);
						", serviceCode:".write;
						i.write;
						", ".write;
						service.serviceAttribute.desc.write;
						", keyVer:".write;
						writef("[%02x, %02x]", keyVer[0], keyVer[1]);
						"]".writeln;
					}
					nodes = [];
				}
				break;
			case "searchSrvAll":
				for(int i = 0; i <= 0xffff; i++)
				{
					ushort index = cast(ushort)i;
					auto rcv = searchService(lastTag, index);
					if(rcv == [0xff, 0xff])
					{
						break;
					}
					writef("num:%04x", index);
					if(rcv.length == 4)
					{
						auto srv = Service([rcv[0], rcv[1]]);
						writef(", %s, ", srv.serviceAttribute.desc);
					}
					rcv.print;
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
				requestService(lastTag, nodes).nodePrint;
				break;
			case "searchSrv":
				"index:".write;
				ushort index = readln.chomp.to!ushort(16);
				searchService(lastTag, index).print;
				break;
			case "reqSys":
				data ~= 0x0c;
				data ~= lastTag.idm;
				auto d = lastTag.command(data);
				if(d.length < 10) {
					"no data".writeln;
					break;
				}
				d = d[9..$];
				auto count = d[0];
				d = d[1..$];
				if(d.length != count * 2) {
					"invalid data".writeln;
					break;
				}
				ushort[] sysCode;
				for(int i = 0; i < count; i++) {
					ushort code = (cast(ushort)d[0]) << 8 | d[1];
					writef("%04x, ", code);
					sysCode ~= code;
					d = d[2..$];
				}
				writeln;
				break;
			case "reqRes":
				data ~= 0x04;
				data ~= lastTag.idm;
				lastTag.command(data).print;
				break;
			case "read":
				auto sb = ServiceBlock();
				Service bsrv = Service(0, ServiceAttribute.INVALIDE_SERVICE);
				"block count:".write;
				ubyte blockCount = readln.chomp.to!ubyte;
				for(int i = 0; i < blockCount; i++){
					ushort sn;
					Service srv;
					"service num".write;
					if(bsrv.serviceAttribute != ServiceAttribute.INVALIDE_SERVICE){
						"(default ".write;
						bsrv.serviceNumber.write;
						")".write;
					}
					":".write;
					string snStr = readln.chomp;
					if(snStr == "" && bsrv.serviceAttribute != ServiceAttribute.INVALIDE_SERVICE){
						sn = bsrv.serviceNumber;
					}else{
						sn = snStr.to!ushort;
					}
					"choose service attr".writeln;
					foreach(member; EnumMembers!ServiceAttribute){
						if(member == ServiceAttribute.INVALIDE_SERVICE){
							continue;
						}
						"  ".write;
						member.attr.write;
						":".write;
						member.write;
						if(member == bsrv.serviceAttribute){
							"(default)".write;
						}
						"".writeln;
					}
					while(true){
						try{
							"service attr:".write;
							string sa = readln.chomp;
							if(sa == ""){
								if(bsrv.serviceAttribute != ServiceAttribute.INVALIDE_SERVICE){
									srv = bsrv;
									break;
								}
							}else{
								srv = Service(sn, sa.to!ubyte.to!ServiceAttribute);
								bsrv = srv;
								break;
							}
						}catch(Exception e){
						}
					}
					"block num:".write;
					ushort blockNum = readln.chomp.to!ushort;
					sb.add(srv, blockNum);
				}
				auto blockData = lastTag.readWithoutEncryption(sb);
				if(blockData.length == 0){
					break;
				}
				if(lastTag.systemCode.canFind(0x0003)){
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
					if(lastTag is null) {
						continue;
					}
					if(lastTag.systemCode.canFind([0x0003], [0x865e])){
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
