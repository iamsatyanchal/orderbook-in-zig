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
    price: u64,
    timestamp: u128,
    status: OrderStatus,
};

const PriceLevel = struct {
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

fn createOrder(id: u64, side: Side, quantity: u64, price: u64) Order {
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

fn toTicks(price: f64) u64 {
    return @intFromFloat(price * 100.0);
}

fn toFloat(price: u64) f64 {
    return @as(f64, @floatFromInt(price)) / 100.0;
}

const OrderBook = struct {
    bids: std.AutoHashMap(u64, PriceLevel),
    asks: std.AutoHashMap(u64, PriceLevel),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) OrderBook {
        return .{
            .bids = std.AutoHashMap(u64, PriceLevel).init(allocator),
            .asks = std.AutoHashMap(u64, PriceLevel).init(allocator),
            .allocator = allocator,
        };
    }

    fn deinit(self: *OrderBook) void {
        self.bids.deinit();
        self.asks.deinit();
    }

    fn addOrder(self: *OrderBook, order: Order) !void {
        const mapping = if (order.side == .buy) &self.bids else &self.asks;

        const result = try mapping.getOrPut(order.price);

        if (result.found_existing) {
            try result.value_ptr.addOrder(order);
        } else {
            result.value_ptr.* = PriceLevel.init(order.price, self.allocator);
            try result.value_ptr.addOrder(order);
        }
    }

    fn asc_compare(ctx: void, a: u64, b: u64) bool {
        _ = ctx;
        return a < b;
    }

    fn desc_compare(ctx: void, a: u64, b: u64) bool {
        _ = ctx;
        return a > b;
    }

    fn print(self: *const OrderBook) !void {
        show("\n========== ORDER BOOK ==========\n", .{});
        const ask_keys = self.asks.keys();
        if (ask_keys.len > 0) {
            const sorted_asks = try self.allocator.alloc(u64, ask_keys.len);
            defer self.allocator.free(sorted_asks);
            @memcpy(sorted_asks, ask_keys);
            std.mem.sort(u64, sorted_asks, {}, asc_compare);
            for (sorted_asks) |price| {
                const level = self.asks.get(price).?;
                show("  {d:.2} | Qty: {d} | Orders: {d}\n", .{
                    toFloat(level.price),
                    level.totalQuantity(),
                    level.orders.items.len,
                });
            }
        }

        show("--------------- SPREAD ---------------\n", .{});

        const bid_keys = self.bids.keys();
        if (bid_keys.len > 0) {
            const sorted_bids = try self.allocator.alloc(u64, bid_keys.len);
            defer self.allocator.free(sorted_bids);
            @memcpy(sorted_bids, bid_keys);
            std.mem.sort(u64, sorted_bids, {}, desc_compare);
            for (sorted_bids) |price| {
                const level = self.bids.get(price).?;
                show("  {d:.2} | Qty: {d} | Orders: {d}\n", .{
                    toFloat(level.price),
                    level.totalQuantity(),
                    level.orders.items.len,
                });
            }
        }
        show("====================================\n", .{});
    }
};

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var book = OrderBook.init(alloc);
    defer book.deinit();

    // Random order mein daal ke dekhte hain
    try book.addOrder(createOrder(3, .buy, 500, toTicks(149.00)));
    try book.addOrder(createOrder(5, .sell, 100, toTicks(151.50)));
    try book.addOrder(createOrder(1, .buy, 100, toTicks(150.50))); // toTicks hata diya, direct int
    try book.addOrder(createOrder(4, .sell, 50, toTicks(152.00)));
    try book.addOrder(createOrder(2, .buy, 200, toTicks(150.50)));

    try book.print();
}
