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

const Trade = struct {
    buy_order_id: u64,
    sell_order_id: u64,
    price: u64,
    quantity: u64,
    timestamp: u128,
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

        show("Asks:\n", .{});
        const ask_keys_count = self.asks.count();
        if (ask_keys_count > 0) {
            const sorted_asks = try self.allocator.alloc(u64, ask_keys_count);
            defer self.allocator.free(sorted_asks);

            var i: usize = 0;
            var ask_it = self.asks.iterator();
            while (ask_it.next()) |entry| {
                sorted_asks[i] = entry.key_ptr.*;
                i += 1;
            }

            std.mem.sort(u64, sorted_asks, {}, asc_compare);
            for (sorted_asks) |price| {
                if (self.asks.get(price)) |level| {
                    show("  {d:.2} | Qty: {d} | Orders: {d}\n", .{
                        toFloat(level.price),
                        level.totalQuantity(),
                        level.orders.items.len,
                    });
                }
            }
        }

        show("--------------------------------\n", .{});
        show("Bids:\n", .{});
        const bids_keys_count = self.bids.count();
        if (bids_keys_count > 0) {
            const sorted_bids = try self.allocator.alloc(u64, bids_keys_count);
            defer self.allocator.free(sorted_bids);

            var j: usize = 0;
            var bids_it = self.bids.iterator();
            while (bids_it.next()) |entry| {
                sorted_bids[j] = entry.key_ptr.*;
                j += 1;
            }

            std.mem.sort(u64, sorted_bids, {}, desc_compare);
            for (sorted_bids) |price| {
                if (self.bids.get(price)) |level| {
                    show("  {d:.2} | Qty: {d} | Orders: {d}\n", .{
                        toFloat(level.price),
                        level.totalQuantity(),
                        level.orders.items.len,
                    });
                }
            }
        }
        show("================================\n", .{});
    }

    fn matchOrder(self: *OrderBook, incoming: *Order, trades: *std.ArrayList(Trade)) !void {
        const oppo_matching = if (incoming.side == .buy) &self.asks else &self.bids;

        while (incoming.quantity > 0) {
            var best_price: ?u64 = null;
            var oppo_it = oppo_matching.iterator();

            while (oppo_it.next()) |entry| {
                const price_level = entry.value_ptr.*;
                if (best_price == null) {
                    best_price = price_level.price;
                } else if (incoming.side == .buy and price_level.price < best_price.?) {
                    best_price = price_level.price;
                } else if (incoming.side == .sell and price_level.price > best_price.?) {
                    best_price = price_level.price;
                }
            }

            if (best_price == null) break;

            const hitting = if (incoming.side == .buy)
                incoming.price >= best_price.?
            else
                incoming.price <= best_price.?;

            if (!hitting) break;

            var level = oppo_matching.get(best_price.?).?;
            var rest_orders = &level.orders.items[0];

            const trade_qty = @min(incoming.quantity, rest_orders.quantity);
            try trades.append(Trade{
                .buy_order_id = if (incoming.side == .buy) incoming.id else rest_orders.id,
                .sell_order_id = if (incoming.side == .sell) incoming.id else rest_orders.id,
                .price = level.price,
                .quantity = trade_qty,
                .timestamp = @intCast(std.time.nanoTimestamp()),
            });

            incoming.quantity = incoming.quantity - trade_qty;
            rest_orders.quantity = rest_orders.quantity - trade_qty;

            if (rest_orders.quantity == 0) {
                _ = level.orders.orderedRemove(0);
                if (level.orders.items.len == 0) {
                    _ = oppo_matching.remove(best_price.?);
                    level.deinit();
                }
            }
            if (incoming.quantity > 0) {
                try self.addOrder(incoming.*);
            }
        }
    }
};

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var book = OrderBook.init(alloc);
    defer book.deinit();

    // Trades store karne ke liye list
    var trades = std.ArrayList(Trade).init(alloc);
    defer trades.deinit();

    show("\n[1] Adding some SELL orders first...\n", .{});
    try book.addOrder(createOrder(10, .sell, 50, toTicks(152.00)));
    try book.addOrder(createOrder(13, .sell, 20, toTicks(352.00)));
    try book.addOrder(createOrder(11, .sell, 100, toTicks(151.50)));
    try book.addOrder(createOrder(14, .buy, 20, toTicks(352.00)));

    try book.print();

    show("\n[2] Incoming BUY order: ID=20, Qty=80, Price=152.00\n", .{});

    var new_buy = createOrder(20, .buy, 80, toTicks(152.00));
    try book.matchOrder(&new_buy, &trades);

    show("\n[3] Trades Executed:\n", .{});
    for (trades.items) |trade| {
        show("  BUY#{d} <-> SELL#{d} | Qty: {d} | Price: {d:.2}\n", .{
            trade.buy_order_id,
            trade.sell_order_id,
            trade.quantity,
            toFloat(trade.price),
        });
    }

    show("\n[4] Order Book AFTER Match:\n", .{});
    try book.print();

    show("\n[5] Check Incoming Order Status: Remaining Qty = {d}\n", .{new_buy.quantity});
}
