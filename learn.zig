const std = @import("std");
const show = std.debug.print;
const Side = enum {
    buy,
    sell,
};

const OrderStatus = enum {
    new,
    partially_filled,
    filled,
    cancelled,
};

const Order = struct {
    id: u64,
    side: Side,
    quantity: u64,
    price: f64,
    timestamp: u128,
    status: OrderStatus,
};

const PriceLevel = struct {
    price: f64,
    orders: std.ArrayList(Order),

    fn init(allocator: std.mem.Allocator, price: f64) PriceLevel {
        return .{
            .price = price,
            .orders = std.ArrayList(Order).init(allocator),
        };
    }

    fn addOrder(self: *PriceLevel, order: Order) !void {
        try self.append(order);
    }

    fn totalQuant(self: *PriceLevel) u64 {
        var total: u64 = 0;
        for (self.orders.item) |order| {
            total = total + order.quantity;
        }
        return total;
    }
};

fn createOrder(id: u64, side: Side, quantity: u64, price: f64) Order {
    std.debug.assert(price > 0.0);
    std.debug.assert(quantity > 0);

    return Order{
        .id = id,
        .side = side,
        .quantity = quantity,
        .price = price,
        .timestamp = @intCast(std.time.nanoTimestamp()),
        .status = .new, // jab bhi order bane, status = new
    };
}

fn statusToString(status: OrderStatus) []const u8 {
    return switch (status) {
        .new => "NEW",
        .partially_filled => "PARTIAL",
        .filled => "FILLED",
        .cancelled => "CANCELLED",
    };
}

fn sideToString(side: Side) []const u8 {
    return switch (side) {
        .buy => "BUY",
        .sell => "SELL",
    };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var orders = std.ArrayList(Order).init(allocator);
    defer orders.deinit();

    try orders.append(createOrder(1, .buy, 100, 150.50));
    try orders.append(createOrder(2, .sell, 50, 152.00));
    try orders.append(createOrder(3, .buy, 200, 145.00));
    try orders.append(createOrder(4, .sell, 150, 148.50));
    try orders.append(createOrder(5, .buy, 300, 150.00));

    for (orders.items, 0..) |order, i| {
        show("[{d}] ID: {d}, Side: {s}, Quantity: {d}, Price: {d}, Timestamp: {d}, Status: {s}\n", .{ i, order.id, sideToString(order.side), order.quantity, order.price, order.timestamp, statusToString(order.status) });
    }
}
