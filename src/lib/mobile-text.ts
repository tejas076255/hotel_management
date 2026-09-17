import { addDays, listNights } from "@/lib/dates";

type SummaryReservation = {
  name: string;
  roomTypeThai: string;
  checkinDate: string;
  checkoutDate: string;
  nights: number;
  price: number;
  dailyPrices: number[];
};

type AvailabilityDisplayConfig = {
  key: string;
  name: string;
  aliases: string[];
  linkLabel: string;
};

export const MOBILE_TEXT_ROOM_DISPLAY: AvailabilityDisplayConfig[] = [
  {
    key: "double_standard",
    name: "Roomธรรมดา เตียงเดี่ยว",
    aliases: ["double standard", "Roomธรรมดาเตียงเดี่ยว"],
    linkLabel: "Roomธรรมดา",
  },
  {
    key: "twin_standard",
    name: "Roomธรรมดา เตียงคู่",
    aliases: ["twin standard", "Roomธรรมดาเตียงคู่"],
    linkLabel: "Roomธรรมดา",
  },
  {
    key: "deluxe_queen",
    name: "Roomดีลักซ์ เตียงเดี่ยว",
    aliases: ["deluxe queen", "Roomดีลักซ์เตียงเดี่ยว"],
    linkLabel: "Roomดีลักซ์",
  },
  {
    key: "deluxe_twin",
    name: "Roomดีลักซ์ เตียงคู่",
    aliases: ["deluxe twin", "Roomดีลักซ์เตียงคู่"],
    linkLabel: "Roomดีลักซ์",
  },
  {
    key: "triple_beds",
    name: "Roomสามเตียง",
    aliases: ["triple beds", "Roomสามเตียง"],
    linkLabel: "Roomสามเตียง",
  },
  {
    key: "junior_suite",
    name: "Roomใหญ่ เตียงคิง",
    aliases: ["junior suite", "Roomใหญ่เตียงคิง"],
    linkLabel: "Roomใหญ่ เตียงคิง",
  },
  {
    key: "family_room",
    name: "Roomแฟมิลี่ (พักได้ 3 ท่าน ค่ะ)",
    aliases: ["family room", "Roomแฟมิลี่"],
    linkLabel: "Roomแฟมิลี่",
  },
];

export const MOBILE_TEXT_ROOM_LINKS: Record<string, string> = {
  Roomธรรมดา: "https://photos.app.goo.gl/mx3kJMCvRWt8x33d7",
  Roomดีลักซ์: "https://photos.app.goo.gl/c94VaCBth1dPvTScA",
  Roomสามเตียง: "https://photos.app.goo.gl/QV2Y4mifSCfhHKFf8",
  "Roomใหญ่ เตียงคิง": "https://photos.app.goo.gl/5Skn5eH3AzvXQQh78",
  Roomแฟมิลี่: "https://photos.app.goo.gl/ReiwqRvkmPpVJRmx5",
};

const THAI_MONTHS = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

function parseYmd(value: string): Date {
  return new Date(`${value}T12:00:00+07:00`);
}

function formatMoney(value: number): string {
  return Number(value || 0).toLocaleString("th-TH", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  });
}

export function formatThaiDayMonth(value: string): string {
  const date = parseYmd(value);
  return `${date.getDate()} ${THAI_MONTHS[date.getMonth()]}`;
}

export function normalizeAlphaNumUpper(value: string): string {
  return String(value ?? "")
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .trim();
}

export function formatPriceBreakdown(dailyPrices: number[]): string {
  if (!dailyPrices || dailyPrices.length === 0) return "";
  const normalized = dailyPrices.map((price) => Number(price || 0));
  const firstPrice = normalized[0] ?? 0;
  if (normalized.every((price) => price === firstPrice)) {
    return `PriceReturnละ ${formatMoney(firstPrice)}`;
  }

  const counts = new Map<number, number>();
  for (const price of normalized) {
    counts.set(price, (counts.get(price) ?? 0) + 1);
  }

  return Array.from(counts.entries())
    .map(([price, count]) => `PriceReturnละ ${formatMoney(price)} ${count} Return`)
    .join(", ");
}

export function formatBookingSummaryText(summaries: SummaryReservation[]): string {
  if (summaries.length === 0) return "";

  const totalPrice = summaries.reduce((sum, item) => sum + Number(item.price || 0), 0);
  let text = "สรุปการจองของคุณCustomerนะคะ\n";

  if (summaries.length === 1) {
    const item = summaries[0];
    text += `คุณ${item.name}\n`;
    text += `- จอง${item.roomTypeThai}\n`;
    text += `- เข้าพักDate ${formatThaiDayMonth(item.checkinDate)} - Daysออก: ${formatThaiDayMonth(item.checkoutDate)}\n`;
    text += `- รวมQuantity ${item.nights} Return ${formatPriceBreakdown(item.dailyPrices)}\n`;
    text += `Priceรวม ${formatMoney(item.price)} THB ค่ะ`;
    return text;
  }

  text += `คุณ${summaries[0].name}\n`;
  summaries.forEach((item, index) => {
    text += `\nRoomที่ ${index + 1}:\n`;
    text += `- จอง${item.roomTypeThai}\n`;
    text += `- เข้าพักDate ${formatThaiDayMonth(item.checkinDate)} - Daysออก: ${formatThaiDayMonth(item.checkoutDate)}\n`;
    text += `- รวมQuantity ${item.nights} Return ${formatPriceBreakdown(item.dailyPrices)}\n`;
    text += `- Price ${formatMoney(item.price)} THB\n`;
  });
  text += `\nPriceรวมAll ${formatMoney(totalPrice)} THB ค่ะ`;
  return text;
}

export function resolveRoomDisplayConfig(nameEn?: string | null, nameTh?: string | null): AvailabilityDisplayConfig | null {
  const candidates = [String(nameEn ?? ""), String(nameTh ?? "")]
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);

  for (const config of MOBILE_TEXT_ROOM_DISPLAY) {
    if (config.aliases.some((alias) => candidates.some((item) => item.includes(alias)))) {
      return config;
    }
  }

  return null;
}

export function resolveRoomTypeThaiLabel(nameEn?: string | null, nameTh?: string | null): string {
  const thai = String(nameTh ?? "").trim();
  if (thai) return thai.replace(/\s+/g, "");

  const display = resolveRoomDisplayConfig(nameEn, nameTh);
  if (display) {
    return display.name.replace(/\s+/g, "");
  }

  return String(nameEn ?? "ไม่ทราบCategory").trim() || "ไม่ทราบCategory";
}

type AvailabilityDayData = Record<
  string,
  {
    price: number;
    available: boolean;
  }
>;

function samePricesOnly(left: AvailabilityDayData, right: AvailabilityDayData): boolean {
  const keys = Object.keys(left);
  for (const key of keys) {
    if ((left[key]?.price ?? 0) !== (right[key]?.price ?? 0)) return false;
  }
  return true;
}

function computeCombinedAvailability(daysData: AvailabilityDayData[]) {
  const combined: Record<string, { price: number; status: "available" | "full" | "partial" }> = {};
  Object.keys(daysData[0] ?? {}).forEach((key) => {
    let availableCount = 0;
    for (const day of daysData) {
      if (day[key]?.available) availableCount += 1;
    }
    combined[key] = {
      price: Number(daysData[0]?.[key]?.price ?? 0),
      status:
        availableCount === daysData.length
          ? "available"
          : availableCount === 0
            ? "full"
            : "partial",
    };
  });
  return combined;
}

export function groupAvailabilityDaysByPriceOnly(pricesByDay: Record<string, AvailabilityDayData>) {
  const days = Object.keys(pricesByDay).sort();
  if (days.length === 0) return [];

  const chunks: Array<{
    startDate: string;
    endDate: string;
    daysData: AvailabilityDayData[];
    combinedPrices: Record<string, { price: number; status: "available" | "full" | "partial" }>;
  }> = [];

  let current = {
    startDate: days[0],
    endDate: days[0],
    daysData: [pricesByDay[days[0]]],
    combinedPrices: computeCombinedAvailability([pricesByDay[days[0]]]),
  };

  for (let index = 1; index < days.length; index += 1) {
    const currentDay = days[index];
    if (samePricesOnly(current.daysData[0], pricesByDay[currentDay])) {
      current.endDate = currentDay;
      current.daysData.push(pricesByDay[currentDay]);
      current.combinedPrices = computeCombinedAvailability(current.daysData);
    } else {
      chunks.push(current);
      current = {
        startDate: currentDay,
        endDate: currentDay,
        daysData: [pricesByDay[currentDay]],
        combinedPrices: computeCombinedAvailability([pricesByDay[currentDay]]),
      };
    }
  }

  chunks.push(current);
  return chunks;
}

export function formatAvailabilityText(pricesByDay: Record<string, AvailabilityDayData>): string {
  const chunks = groupAvailabilityDaysByPriceOnly(pricesByDay);
  let text = "";

  chunks.forEach((chunk, index) => {
    const dateText =
      chunk.startDate === chunk.endDate
        ? formatThaiDayMonth(chunk.startDate)
        : `${formatThaiDayMonth(chunk.startDate)} - ${formatThaiDayMonth(chunk.endDate)}`;
    text += `PriceRoomเข้าพักDate ${dateText} ค่ะ\n`;

    MOBILE_TEXT_ROOM_DISPLAY.forEach((room, roomIndex) => {
      const row = chunk.combinedPrices[room.key];
      if (!row) return;
      if (row.status === "available") {
        text += `${roomIndex + 1}. ${room.name} Price ${formatMoney(row.price)}/Return\n`;
      } else if (row.status === "partial") {
        text += `${roomIndex + 1}. ${room.name} มีว่างแต่ไม่ครบทุกDays ค่ะ\n`;
      } else {
        text += `${roomIndex + 1}. ${room.name} เต็มค่ะ\n`;
      }
    });

    if (index < chunks.length - 1) text += "\n";
  });

  text += "\nRoomธรรมดาจะเป็นRoomที่ยังไม่ได้ปReceiveปรุงค่ะ ส่วนที่เหลือปReceiveปรุงใหม่หมดแล้วค่ะ\n";
  text += "ดูรูปRoomได้ที่นี่ค่ะ\n";
  Object.entries(MOBILE_TEXT_ROOM_LINKS).forEach(([label, link]) => {
    text += `- ${label}: ${link}\n`;
  });

  return text.trim();
}

type PriceQuoteRoom = {
  roomTypeName: string;
  quantity: number;
  dailyPrices: number[];
};

function compactThaiRoomName(name: string): string {
  return String(name ?? "").replace(/\s+/g, "");
}

export function formatPriceQuoteText(input: {
  customerName: string;
  checkin: string;
  checkout: string;
  nights: number;
  rooms: PriceQuoteRoom[];
}): string {
  const customerName = String(input.customerName ?? "")
    .replace(/^คุณ\s*/i, "")
    .trim() || "Customer";
  const nights = Math.max(1, Number(input.nights || 1));
  const rooms = input.rooms.filter((room) => Number(room.quantity) > 0);
  const totalAll = rooms.reduce((sum, room) => {
    const perRoomTotal = room.dailyPrices.reduce((itemSum, price) => itemSum + Number(price || 0), 0);
    return sum + perRoomTotal * Number(room.quantity || 0);
  }, 0);

  let text = `สรุปCategoryRoomและPriceตามที่คุณ ${customerName} สอบถามมานะคะ\n`;
  text += `เข้าพักDate ${formatThaiDayMonth(input.checkin)} - Daysออก: ${formatThaiDayMonth(input.checkout)} รวม ${nights} Return\n`;

  for (const room of rooms) {
    const quantity = Math.max(1, Number(room.quantity || 1));
    const perRoomTotal = room.dailyPrices.reduce((sum, price) => sum + Number(price || 0), 0);
    const lineTotal = perRoomTotal * quantity;
    const normalizedPrices = room.dailyPrices.map((price) => Number(price || 0));
    const firstPrice = normalizedPrices[0] ?? 0;
    const samePrice = normalizedPrices.length > 0 && normalizedPrices.every((price) => price === firstPrice);

    text += `\n${compactThaiRoomName(room.roomTypeName)} Quantity ${quantity} Room\n`;
    if (samePrice) {
      text += `- PriceReturnละ ${formatMoney(firstPrice)} THB/Room x ${nights} Return\n`;
    } else {
      const detail = normalizedPrices
        .map((price, index) => `${formatThaiDayMonth(addDays(input.checkin, index))} ${formatMoney(price)} THB`)
        .join(", ");
      text += `- PriceตามDate ${detail}\n`;
    }
    if (quantity === 1) {
      text += `- Priceรวม ${formatMoney(lineTotal)} THB\n`;
    } else {
      text += `- Price ${formatMoney(perRoomTotal)} THB/Room Priceรวม ${formatMoney(lineTotal)} THB\n`;
    }
  }

  text += `\nPriceรวมAll ${formatMoney(totalAll)} THBค่ะ`;
  return text;
}

export function buildDailyPriceMap(
  roomTypeKey: string,
  checkin: string,
  checkout: string,
  dailyRows: Array<{ stay_date: string; price: number; available: boolean }>
): Record<string, AvailabilityDayData> {
  const nights = listNights(checkin, checkout);
  const result: Record<string, AvailabilityDayData> = {};
  for (const stayDate of nights) {
    if (!result[stayDate]) result[stayDate] = {};
    const row = dailyRows.find((item) => item.stay_date === stayDate);
    result[stayDate][roomTypeKey] = {
      price: Number(row?.price ?? 0),
      available: Boolean(row?.available),
    };
  }
  return result;
}
