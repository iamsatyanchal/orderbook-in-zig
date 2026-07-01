const std = @import("std");
const types = @import("types.zig");
const memory = std.mem;
const show = std.debug.print;

const OrderPacket = types.OrderPacket;

pub const Errors = error{ Incomplete, Invalid };

pub fn parseBytes(buffer: []const u8, bytes_read: usize, orders_out: *std.ArrayList(types.Order)) !void {
    const packet_size = @sizeOf(OrderPacket);
    var offset: usize = 0;

    while (offset + packet_size <= bytes_read) {
        const packet_bytes = buffer[offset .. offset + packet_size];
        const pkt = memory.bytesAsValue(OrderPacket, packet_bytes);

        if (pkt.side > 1) {
            return Errors.Invalid;
        }

        const order = types.createOrder(
            pkt.id,
            if (pkt.side == 0) .buy else .sell,
            pkt.quantity,
            pkt.price,
        );

        try orders_out.append(order);

        offset = offset + packet_size;
    }

    if (offset < bytes_read) {
        show("{d} bytes left in buffer", .{bytes_read - offset});
    }
}
