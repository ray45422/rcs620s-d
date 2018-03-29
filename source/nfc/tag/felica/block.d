module nfc.tag.felica.command;
import std.conv;

struct BlockList{
	this(ushort blockNumber, ubyte serviceCodeNumber = 0, ubyte accessMode = 0b00){
		this.blockNum = blockNumber;
		this.srvCodeNum = serviceCodeNumber;
		this.accessMode = accessMode;
	}
	ubyte[] pack(){
		ubyte[] block;
		if(blockNum > 0xff){
			block ~= ((accessMode & 0b111) << 4) | (srvCodeNum & 0b1111);
			block ~= (blockNum & 0xff).to!ubyte;
			block ~= (blockNum >> 8).to!ubyte;
		}else{
			block ~= 0b10000000 | ((accessMode & 0b111) << 4) | (srvCodeNum & 0b1111);
			block ~= blockNum.to!ubyte;
		}
		return block;
	}
private:
	ushort blockNum;
	ubyte srvCodeNum;
	ubyte accessMode;
}
unittest{
	//block number
	assert(BlockList(0).pack == [0b10000000, 0b0]);
	assert(BlockList(511).pack == [0b0, 0b11111111, 0b1]);
	//service code number
	assert(BlockList(0, 1).pack == [0b10000001, 0b0]);
	assert(BlockList(0, 15).pack == [0b10001111, 0b0]);
	//access mode
	assert(BlockList(0, 0, 1).pack == [0b10010000, 0b0]);
}
