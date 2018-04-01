module nfc.tag.felica.serviceBlock;
import std.conv;
public import nfc.tag.felica.service;
public import nfc.tag.felica.block;

struct ServiceBlock{
	this(Service service, ushort blockNumber, ubyte accessMode = 0b00){
		add(service, blockNumber, accessMode);
	}
	this(Service service, Block block){
		this([service], [block]);
	}
	this(Service[] services, Block[] blocks){
		this._services = services;
		this._blocks = blocks;
	}
	void add(Service service, ushort blockNumber, ubyte accessMode = 0b00){
		foreach(ubyte i, srv; _services){
			if(srv == service){
				_blocks ~= Block(blockNumber, i, accessMode);
				return;
			}
		}
		_services ~= service;
		add(service, blockNumber, accessMode);
	}
	ubyte[] pack(){
		ubyte[] data;
		data ~= _services.length.to!ubyte;
		foreach(srv; _services){
			data ~= srv.pack;
		}
		data ~= _blocks.length.to!ubyte;
		foreach(blk; _blocks){
			data ~= blk.pack;
		}
		return data;
	}
private:
	Service[] _services;
	Block[] _blocks;
}
unittest{
	ubyte[] data = [
		0x02,       //data count:2
		0x08, 0x00, //srv num:0, srv attr:RANDOM_RW_AUTH(0b1000), (srv index:0)
		0x09, 0x00, //srv num:0, srv attr:RANDOM_RW_NOAUTH(0b1001), (srv index:1)
		0x05,       //data count:5
		0x80, 0x00, //type:2byte(0b10000000), access mode:0, srv list index:0, block num:0
		0x80, 0x01, //type:2byte(0b10000000), access mode:0, srv list index:0, block num:1
		0x81, 0x00, //type:2byte(0b10000000), access mode:0, srv list index:1, block num:0
		0x80, 0x02, //type:2byte(0b10000000), access mode:0, srv list index:0, block num:2
		0x00, 0xff, 0x03, //type:3byte(0b00000000), access mode:0, srv list index:0, block num:1023(Little Endian)
	];
	auto srv1 = Service(0, ServiceAttribute.RANDOM_RW_AUTH);
	auto srv2 = Service(0, ServiceAttribute.RANDOM_RW_NOAUTH);
	auto sb = ServiceBlock(srv1, 0);
	sb.add(srv1, 1);
	sb.add(srv2, 0);
	sb.add(srv1, 2);
	sb.add(srv1, 1023);
	assert(sb.pack == data);
}
