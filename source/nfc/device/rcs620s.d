module nfc.device.rcs620s;
import std.stdio;
import std.array;
import std.conv;
import core.thread;
import serial.device;
import nfc.device;
import nfc.tag.felica;

class RCS620S: Device{
public:
	this(string path){
		this(new SerialPort(path, dur!("msecs")(90), dur!("msecs")(90)));
	}
	this(SerialPort port){
		this.port=port;
		this.port.speed(BaudRate.BR_115200);
		this.timeout = RCS620S_DEFAULT_TIMEOUT;
	}
	bool getFirmwareVersion(){
		ubyte[] data = [0xd4, 0x02];
		auto rcv = rwCommand(data);
		if(rcv == [0xd5, 0x03, 0x33, 0x01, 0x30, 0x07]){
			return true;
		}
		return false;
	}
	FeliCa[] polling(ubyte count = 0x01, ubyte speed = 0x01, uint systemCode = 0xffff, ubyte requestCode = 0x00){
		import std.stdio;
		ubyte[] data = [0xd4, 0x4a, count, speed, 0x00, 0xff, 0xff, requestCode, 0x00];
		data[5] = (systemCode >> 8) & 0xff;
		data[6] = systemCode & 0xff;
		if(data[2] != 1){
			data[8] = 0x0f;
		}
		FeliCa[] tags;
		auto rcv = rwCommand(data);
		if(rcv.length <= 3){
			return tags;
		}
		if(rcv[0..2] != [0xd5, 0x4b]){
			return tags;
		}
		auto tagCount = rcv[2];
		rcv = rcv[3..$];
		for(int i = 0; i < tagCount; ++i){
			auto len = rcv[1];
			auto felica = FeliCa.factory(rcv[3..11], rcv[11..19], this);
			if(requestCode == 1){
				felica.addSystemCode(rcv[19..21]);
			}
			if(requestCode == 2){
				felica.setCommunicationSpec(rcv[19..21]);
			}
			tags ~= felica;
			rcv = rcv[(len+1)..$];
		}
		return tags;
	}
	bool polling(uint systemCode = 0xffff){
		ubyte[] response;
		/* InListPassiveTarget */
		ubyte[9] buf = [0xd4, 0x4a, 0x01, 0x01, 0x00, 0xff, 0xff, 0x00, 0x00];
		buf[5] = cast(ubyte)((systemCode >> 8) & 0xff);
		buf[6] = cast(ubyte)((systemCode >> 0) & 0xff);

		response = rwCommand(buf);
		if(response.length == 0 || response.length != 22 || !cmp(response, [0xd5, 0x4b, 0x01, 0x01, 0x12, 0x01], 6)){
			return false;
		}

		idm = response[6..14];
		pmm = response[14..22];

		return true;
	}
	bool rfOff(){
		ubyte[] response;

		/* RFConfiguration (RF field) */
		response = rwCommand([0xd4, 0x32, 0x01, 0x00]);
		if(response.length ==0 || response.length != 2 || !cmp(response, [0xd5, 0x33], 2)){
			return false;
		}
		return true;
	}
	/*TODO テストコードからの移植
	  エラーチェックなど追加
	*/
	ubyte[] rfOn(){
		ubyte[] data = [0xd4, 0x32, 0x01, 0x01];
		return rwCommand(data);
	}
	ubyte[] getStatus(){
		ubyte[] data = [0xd4, 0x04];
		return rwCommand(data);
	}
	ubyte[] reset(){
		ubyte[] data = [0xd4, 0x18, 0x01];
		return rwCommand(data);
	}
	ubyte[] cardCommand(ubyte[] command, uint timeOut = 400){
		ubyte[] data = [0xd4, 0xa0];
		ushort timeOutHalfSecCount = (timeOut* 2).to!ushort;
		data ~= timeOutHalfSecCount & 0xff;
		data ~= (timeOutHalfSecCount >> 8) & 0xff;
		data ~= 0x00;
		data ~= command;
		data[4] = (data.length - 4).to!ubyte;
		auto rcv = rwCommand(data);
		if(rcv.length <= 2){
			"not enough length".writeln;
			return null;
		}
		if(rcv[0..2] != [0xd5, 0xa1]){
			"not comThruEX data".writeln;
			return null;
		}
		if(rcv[2] != 0x00){
			"com error code:".write;
			writef("%x",rcv[2]);
			return null;
		}
		rcv = rcv[3..$];
		if(rcv[0] != rcv.length){
			"length not same".writeln;
			return null;
		}
		rcv = rcv[1..$];
		return rcv;
	}
	/* end TODO */
	void writeArray(ubyte[] data){
		"[".write;
		foreach(ubyte n; data){
			writef("%2x,", n);
		}
		"]".writeln;
	}
	void close(){
		port.close();
	}
private:
	const uint RCS620S_DEFAULT_TIMEOUT = 1000;
	const uint RCS620S_MAX_CARD_RESPONSE_LEN = 254;
	const uint RCS620S_MAX_RW_RESPONSE_LEN = 265;
	ubyte[8] idm;
	ubyte[8] pmm;
	ulong timeout;
	SerialPort port;
	ubyte[] rwCommand(ubyte[] command){
		ubyte[] buf;
		ubyte dcs;
		ubyte[] response;
		uint responsLen;
		if(command.length <= 255){
			/* normal frame */
			//ubyte[] response;
			//ulong readed=0;
			buf = [0x00, 0x00, 0xff, cast(ubyte)command.length,cast(ubyte)-command.length];
			dcs=calcDCS(command);
			command = buf ~ command;
			buf = [dcs,0x00];
			command = command ~ buf;
			port.write(command);
		} else {
			/* extended frame*/
		}

		/* receive ACK */
		buf = readSerial(6);
		if(buf.length==0 || !cmp(buf, [0x00, 0x00, 0xff, 0x00, 0xff, 0x00],6)){
			cancel("ACK");
			return [];
		}

		/* receive response */
		buf = readSerial(5);
		if(buf.length == 0){
			cancel("receive");
			return [];
		} else if(!cmp(buf, [0x00, 0x00, 0xff],3)){
			return [];
		}
		if(buf[3] == 0xff && buf[4] == 0xff){
			/* extended frame */
		} else {
			/* normal frame */
			if(((buf[3] + buf[4]) & 0xff) != 0){
				return [];
			}
			responsLen = buf[3];
		}
		if(responsLen > RCS620S_MAX_RW_RESPONSE_LEN){
			return [];
		}

		response = readSerial(responsLen);
		if(response.length == 0){
			cancel("receive data");
			return [];
		}

		dcs = calcDCS(response);

		buf = readSerial(2);
		if(buf.length == 0 || buf[0] != dcs || buf[1] != 0x00){
			cancel("can't receive postamble");
			return [];
		}

		return response;
	}
	ubyte[] readSerial(ulong len){
		ubyte[] receive = new ubyte[cast(uint)len];
		ulong readed;
		try{
			readed = port.read(receive);
		}catch(TimeoutException e){
			return [];
		}
		if(readed == len){
			return receive;
		}else{
			receive=receive[0..cast(uint)readed];
			receive=receive~readSerial(len-readed);
			return receive;
		}
	}
	void cancel(string message){
		/*"cancel: ".write;
		message.writeln;*/
		cancel();
	}
	void cancel(){
		/* transmit ACK */
		ubyte[RCS620S_MAX_RW_RESPONSE_LEN] trash;
		port.write([0x00, 0x00, 0xff, 0x00, 0xff, 0x00]);
		Thread.sleep(dur!("msecs")(1));
		try{
			port.read(trash);
		}catch(TimeoutException e){}
	}
	bool cmp(ubyte[] data1, ubyte[] data2, ulong len){
		len--;
		return data1[0..cast(uint)len] == data2[0..cast(uint)len];
	}
	ubyte calcDCS(ubyte[] data){
		ubyte sum = 0;
		for(ulong i = 0; i < data.length; ++i){
			sum += data[cast(uint)i];
		}
		return cast(ubyte)-(sum & 0xff);
	}
}
