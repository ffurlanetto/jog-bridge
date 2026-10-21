import Testing
@testable import jog_bridge

struct ConfigTests {
    private func parse(_ arguments: String...) -> Config {
        Config.parse(["jog-bridge"] + arguments)
    }

    @Test func defaultsTargetTheMP3e2() {
        let config = parse()
        #expect(config.vendorID == 0x06F8)
        #expect(config.productID == 0xB105)
        #expect(config.interface == 0)
        #expect(config.endpointIn == nil)
        #expect(config.portName == "Hercules MP3 e2")
        #expect(config.dump == false)
        #expect(config.listOnly == false)
    }

    @Test func flagsAreRecognised() {
        #expect(parse("--dump").dump)
        #expect(parse("--list").listOnly)
    }

    @Test func nameOverridesThePortName() {
        #expect(parse("--name", "Ma console").portName == "Ma console")
    }

    @Test func productIDAcceptsHexWithAndWithoutPrefix() {
        #expect(parse("--pid", "0xB106").productID == 0xB106)
        #expect(parse("--pid", "b106").productID == 0xB106)
        #expect(parse("--pid", "0XB106").productID == 0xB106)
    }

    @Test func invalidProductIDKeepsTheDefault() {
        #expect(parse("--pid", "zz").productID == 0xB105)
    }

    @Test func interfaceIsDecimal() {
        #expect(parse("--interface", "1").interface == 1)
        #expect(parse("--interface", "x").interface == 0)
    }

    @Test func endpointInAcceptsHex() {
        #expect(parse("--in", "0x81").endpointIn == 0x81)
        #expect(parse("--in", "82").endpointIn == 0x82)
        #expect(parse("--in", "nope").endpointIn == nil)
    }

    @Test func optionsCanBeCombined() {
        let config = parse("--dump", "--pid", "B106", "--in", "0x81", "--name", "Test")
        #expect(config.dump)
        #expect(config.productID == 0xB106)
        #expect(config.endpointIn == 0x81)
        #expect(config.portName == "Test")
    }

    @Test func hexFormatsBytesAsUppercasePairs() {
        #expect(hex([0x90, 0x0A, 0x7F]) == "90 0A 7F")
        #expect(hex([]) == "")
    }
}
