const std = @import("std");
const show = std.debug.print;
pub const Side = enum {
    buy,
    sell,
};

pub const OrderStatus = enum {
    new,
    partially_filled,
    filled,
    cancelled,
};

pub const OrderLocation = struct { side: Side, price: u64 };

pub const Order = struct {
    id: u64,
    side: Side,
    quantity: u64,
    price: u64,
    timestamp: u128,
    status: OrderStatus,
};

pub const Trade = struct {
    buy_order_id: u64,
    sell_order_id: u64,
    price: u64,
    quantity: u64,
    timestamp: u128,
};

pub const PriceLevel = struct {
    price: u64,
    orders: std.ArrayList(Order),

    fn init(price: u64, allocator: std.mem.Allocator) PriceLevel {
        return .{
            .price = price,
            .orders = std.ArrayList(Order).init(allocator),
        };
    }

    fn addOrder(self: *PriceLevel, order: Order) !void {
        try self.orders.append(order);
    }

    fn totalQuantity(self: *const PriceLevel) u64 {
        var total: u64 = 0;
        for (self.orders.items) |order| {
            total = total + order.quantity;
        }
        return total;
    }

    fn deinit(self: *PriceLevel) void {
        self.orders.deinit();
    }
};

pub fn createOrder(id: u64, side: Side, quantity: u64, price: u64) Order {
    std.debug.assert(price > 0.0);
    std.debug.assert(quantity > 0);

    return Order{
        .id = id,
        .side = side,
        .quantity = quantity,
        .price = price,
        .timestamp = @intCast(std.time.nanoTimestamp()),
        .status = .new,
    };
}

// fn statusToString(status: OrderStatus) []const u8 {
//     return switch (status) {
//         .new => "NEW",
//         .partially_filled => "PARTIAL",
//         .filled => "FILLED",
//         .cancelled => "CANCELLED",
//     };
// }

// fn sideToString(side: Side) []const u8 {
//     return switch (side) {
//         .buy => "BUY",
//         .sell => "SELL",
//     };
// }

pub fn toTicks(price: f64) u64 {
    return @intFromFloat(price * 100.0);
}

pub fn toFloat(price: u64) f64 {
    return @as(f64, @floatFromInt(price)) / 100.0;
}

pub const OrderPacket = extern struct {
    id: u32,
    side: u8,
    quantity: u32,
    price: u64,
};

pub fn printPacket(packet: OrderPacket) void {
    const side_str: []const u8 = switch (packet.side) {
        0 => "BUY",
        1 => "SELL",
        else => "UNKNOWN",
    };

    show("Packet -> ID: {d}, Side: {s}, Quantity: {d}, Price: {f}\n", .{
        packet.id,
        side_str,
        packet.quantity,
        toFloat(packet.price),
    });
}
