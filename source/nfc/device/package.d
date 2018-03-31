module nfc.device;

interface Device{
	ubyte[] cardCommand(ubyte[] data, uint timeOut);
}
