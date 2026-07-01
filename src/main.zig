const std = @import("std");
const types = @import("types.zig");
const orderbook = @import("orderbook.zig");
const parser = @import("parser.zig");

const show = std.debug.print;

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var book = orderbook.OrderBook.init(alloc);
    defer book.deinit();

    var trades = std.ArrayList(types.Trade).init(alloc);
    defer trades.deinit();

    // ==========================================
    // FAKE ESP32 DATA GENERATION
    // ==========================================
    // Hum manually bytes bana rahe hain.
    // Tujhe yaad hai? OrderPacket = [u32 id][u8 side][u32 qty][u64 price]

    // Packet 1: BUY 100 shares @ 150.50 (ID=1)
    // 150.50 * 100 = 15050
    const packet1_bytes = [_]u8{
        0x01, 0x00, 0x00, 0x00, // id = 1 (Little Endian)
        0x00, // side = 0 (BUY)
        0x64, 0x00, 0x00, 0x00, // qty = 100
        0xAA, 0x3A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // price = 15050
    };

    // Packet 2: SELL 50 shares @ 151.00 (ID=2)
    // 151.00 * 100 = 15100
    const packet2_bytes = [_]u8{
        0x02, 0x00, 0x00, 0x00, // id = 2
        0x01, // side = 1 (SELL)
        0x32, 0x00, 0x00, 0x00, // qty = 50
        0xDC, 0x3A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // price = 15100
    };

    // Dono packets ko ek bade buffer mein jod do (jaise serial buffer hota hai)
    var serial_buffer: [100]u8 = undefined;
    var total_bytes: usize = 0;

    // @memcpy(serial_buffer[total_bytes..], &packet1_bytes);
    // total_bytes += packet1_bytes.len;

    // @memcpy(serial_buffer[total_bytes..], &packet2_bytes);
    // total_bytes += packet2_bytes.len;

    // Packet 1 copy karo (exact start to end index do)
    const end1 = total_bytes + packet1_bytes.len;
    @memcpy(serial_buffer[total_bytes..end1], &packet1_bytes);
    total_bytes = end1;

    // Packet 2 copy karo
    const end2 = total_bytes + packet2_bytes.len;
    @memcpy(serial_buffer[total_bytes..end2], &packet2_bytes);
    total_bytes = end2;

    show("Received {d} bytes from wire.\n", .{total_bytes});

    // ==========================================
    // PARSING PHASE
    // ==========================================
    var parsed_orders = std.ArrayList(types.Order).init(alloc);
    defer parsed_orders.deinit();

    // Parser ko buffer bhejo
    try parser.parseBytes(&serial_buffer, total_bytes, &parsed_orders);

    show("\nParsed {d} orders successfully!\n", .{parsed_orders.items.len});

    // ==========================================
    // ORDER BOOK PHASE
    // ==========================================
    show("\nFeeding orders into Order Book...\n", .{});
    for (parsed_orders.items) |order| {
        // Yahan directly addOrder nahi, matchOrder use karenge
        // Kyunki agar cross ho rahe hain toh trade ho jayega
        var mutable_order = order;
        try book.matchOrder(&mutable_order, &trades);
    }

    // Trades check
    if (trades.items.len > 0) {
        show("\n*** TRADE OCCURRED ***\n", .{});
        for (trades.items) |trade| {
            show("BUY#{d} <-> SELL#{d} | Qty: {d} | Price: {d:.2}\n", .{
                trade.buy_order_id,
                trade.sell_order_id,
                trade.quantity,
                types.toFloat(trade.price),
            });
        }
    } else {
        show("\nNo trades. Orders resting in book.\n", .{});
    }
}
