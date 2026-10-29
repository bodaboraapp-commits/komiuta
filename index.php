<?php
// ==========================================
// KOMIUTA - Bus Booking Aggregator
// ==========================================

// 1. Get search parameters (default to the ones you provided)

// Sanitize city names: allow letters, spaces, hyphens and apostrophes only (URL-path safe)
function sanitizeCity($value, $default) {
    $value = trim((string)$value);
    if ($value === '' || !preg_match("/^[A-Za-z' \\-]{1,60}$/", $value)) {
        return $default;
    }
    return $value;
}

// Strict YYYY-MM-DD date validation; invalid input falls back to today
function sanitizeDate($value) {
    $value = trim((string)$value);
    $dt = DateTime::createFromFormat('Y-m-d', $value);
    if (!$dt || $dt->format('Y-m-d') !== $value) {
        return date('Y-m-d');
    }
    return $value;
}

$fromCity = sanitizeCity($_GET['from'] ?? 'Nairobi', 'Nairobi');
$toCity = sanitizeCity($_GET['to'] ?? 'Mombasa', 'Mombasa');
$onwardDate = sanitizeDate($_GET['date'] ?? date('Y-m-d'));

// 2. Build the target URL (rawurlencode prevents URL manipulation)
$fromEnc = rawurlencode($fromCity);
$toEnc = rawurlencode($toCity);
$targetUrl = "https://buupass.com/buses/{$fromEnc}-to-{$toEnc}?fromCityName={$fromEnc}&toCityName={$toEnc}&onward={$onwardDate}";

// 3. Fetch the page HTML via cURL. Returns [html, error] — error is null on success.
function fetchHtml($url) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    // Mimic a real browser to avoid basic bot blocking
    curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36');
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);

    $html = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlErrno = curl_errno($ch);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($html === false || $curlErrno !== 0) {
        error_log("[Komiuta] cURL error ({$curlErrno}): {$curlError} for URL: {$url}");
        return [null, "cURL error ({$curlErrno}): {$curlError}"];
    }

    if ($httpCode !== 200 || !$html) {
        error_log("[Komiuta] Unexpected HTTP status {$httpCode} for URL: {$url}");
        return [null, "Unexpected HTTP status {$httpCode}"];
    }

    return [$html, null];
}

// 4. Parse bus result cards from the fetched HTML.
function parseBuses($html) {
    // Parse HTML
    $dom = new DOMDocument();
    libxml_use_internal_errors(true); // Suppress HTML parsing warnings
    $dom->loadHTML($html);
    libxml_clear_errors();
    $xpath = new DOMXPath($dom);

    $buses = [];

    // ⚠️ IMPORTANT: You MUST inspect the actual website (F12 Developer Tools)
    // and update these XPath queries to match the real CSS classes/structure of the site.
    // The below is a generalized example based on common booking site structures.

    $cardNodes = $xpath->query("//div[contains(@class, 'bus') or contains(@class, 'route') or contains(@class, 'card')]");

    foreach ($cardNodes as $node) {
        $text = $node->textContent;

        if (stripos($text, 'Nairobi') !== false && stripos($text, 'Mombasa') !== false) {
            $buses[] = [
                'company' => extractText($xpath, ".//h3 | .//div[contains(@class, 'operator')]", $node),
                'departure' => extractText($xpath, ".//div[contains(@class, 'departure')] | .//time", $node),
                'arrival' => extractText($xpath, ".//div[contains(@class, 'arrival')]", $node),
                'seats' => extractText($xpath, ".//div[contains(@class, 'seats')]", $node),
                'price' => extractText($xpath, ".//div[contains(@class, 'price')] | .//span[contains(@class, 'amount')]", $node),
            ];
        }
    }

    return $buses;
}

// 5. Thin orchestrator: fetch, parse, return null (with logged reason) on failure.
// NOTE: no mock-data fallback — a failed scrape must surface as an explicit
// 'no results' state to the user, never fabricated listings.
function scrapeBusData($url) {
    [$html, $error] = fetchHtml($url);
    if ($error !== null) {
        return null;
    }

    $buses = parseBuses($html);
    if (empty($buses)) {
        error_log("[Komiuta] Scraped page but found 0 bus cards (site structure may have changed or content is JS-rendered): {$url}");
        return null;
    }

    return $buses;
}

// Helper function to safely extract text
function extractText($xpath, $query, $contextNode) {
    $nodes = $xpath->query($query, $contextNode);
    if ($nodes->length > 0) {
        return trim(preg_replace('/\s+/', ' ', $nodes->item(0)->textContent));
    }
    return 'N/A';
}

// Execute scraping
$busResults = scrapeBusData($targetUrl);
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Komiuta - Book Your Bus Ticket</title>
    <style>
        :root {
            --primary: #008060; /* Komiuta Brand Green */
            --primary-dark: #006048;
            --bg: #f4f7f6;
            --text: #333;
            --card-bg: #ffffff;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
        body { background-color: var(--bg); color: var(--text); }

        /* Header */
        header { background: var(--primary); color: white; padding: 1rem 2rem; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .logo { font-size: 1.8rem; font-weight: 800; letter-spacing: -1px; }
        .logo span { color: #a3f7bf; }

        /* Search Box */
        .search-container { background: white; max-width: 900px; margin: -30px auto 30px; padding: 20px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); display: flex; gap: 15px; flex-wrap: wrap; }
        .search-container input, .search-container button { padding: 12px 15px; border: 1px solid #ddd; border-radius: 8px; font-size: 1rem; flex: 1; min-width: 150px; }
        .search-container button { background: var(--primary); color: white; border: none; font-weight: 600; cursor: pointer; flex: 0 0 120px; transition: 0.3s; }
        .search-container button:hover { background: var(--primary-dark); }

        /* Results */
        .results-container { max-width: 900px; margin: 0 auto 50px; padding: 0 20px; }
        .results-header { margin-bottom: 20px; font-size: 1.2rem; color: #555; }

        .bus-card { background: var(--card-bg); border-radius: 12px; padding: 20px; margin-bottom: 15px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 8px rgba(0,0,0,0.04); transition: transform 0.2s; border-left: 5px solid var(--primary); }
        .bus-card:hover { transform: translateY(-3px); box-shadow: 0 6px 15px rgba(0,0,0,0.08); }

        .bus-info { flex: 2; }
        .bus-company { font-size: 1.3rem; font-weight: 700; color: var(--primary-dark); margin-bottom: 8px; }
        .bus-route { font-size: 0.9rem; color: #666; margin-bottom: 12px; }
        .bus-times { display: flex; gap: 30px; font-size: 0.95rem; }
        .time-block strong { display: block; font-size: 1.1rem; color: #222; }
        .time-block span { color: #777; font-size: 0.85rem; }

        .bus-price-action { flex: 1; text-align: right; display: flex; flex-direction: column; align-items: flex-end; gap: 10px; }
        .seats-left { font-size: 0.85rem; color: #e67e22; font-weight: 600; background: #fff3e0; padding: 4px 10px; border-radius: 20px; }
        .price { font-size: 1.5rem; font-weight: 800; color: #222; }
        .book-btn { background: var(--primary); color: white; padding: 10px 25px; border-radius: 8px; text-decoration: none; font-weight: 600; transition: 0.3s; }
        .book-btn:hover { background: var(--primary-dark); }

        .disclaimer { text-align: center; font-size: 0.8rem; color: #888; margin-top: 40px; padding: 20px; }

        @media (max-width: 768px) {
            .bus-card { flex-direction: column; align-items: flex-start; gap: 15px; }
            .bus-price-action { width: 100%; flex-direction: row; justify-content: space-between; align-items: center; }
        }
    </style>
</head>
<body>

    <header>
        <div class="logo">Komiuta<span>.</span></div>
        <nav>
            <a href="#" style="color: white; text-decoration: none; margin-left: 20px;">My Bookings</a>
            <a href="#" style="color: white; text-decoration: none; margin-left: 20px;">Help</a>
        </nav>
    </header>

    <form class="search-container" method="GET" action="">
        <input type="text" name="from" placeholder="From (e.g., Nairobi)" value="<?= htmlspecialchars($fromCity) ?>" required>
        <input type="text" name="to" placeholder="To (e.g., Mombasa)" value="<?= htmlspecialchars($toCity) ?>" required>
        <input type="date" name="date" value="<?= htmlspecialchars($onwardDate) ?>" required>
        <button type="submit">Search</button>
    </form>

    <div class="results-container">
        <div class="results-header">
            Showing buses from <strong><?= htmlspecialchars($fromCity) ?></strong> to <strong><?= htmlspecialchars($toCity) ?></strong> on <strong><?= htmlspecialchars($onwardDate) ?></strong>
        </div>

        <?php if ($busResults): ?>
            <?php foreach ($busResults as $bus): ?>
                <div class="bus-card">
                    <div class="bus-info">
                        <div class="bus-company"><?= htmlspecialchars($bus['company']) ?></div>
                        <div class="bus-route">Route: <?= htmlspecialchars($fromCity) ?> ➝ <?= htmlspecialchars($toCity) ?></div>
                        <div class="bus-times">
                            <div class="time-block">
                                <strong><?= htmlspecialchars($bus['departure']) ?></strong>
                                <span>Departure</span>
                            </div>
                            <div class="time-block">
                                <strong><?= htmlspecialchars($bus['arrival']) ?></strong>
                                <span>Arrival</span>
                            </div>
                        </div>
                    </div>
                    <div class="bus-price-action">
                        <div class="seats-left">🔥 <?= htmlspecialchars($bus['seats']) ?></div>
                        <div class="price"><?= htmlspecialchars($bus['price']) ?></div>
                        <a href="#" class="book-btn">Select Seat</a>
                    </div>
                </div>
            <?php endforeach; ?>
        <?php else: ?>
            <div style="text-align: center; padding: 40px; color: #666;">
                <p>Could not fetch bus data. The target website may have changed its structure or is blocking automated requests.</p>
            </div>
        <?php endif; ?>
    </div>

    <div class="disclaimer">
        <p>⚠️ <strong>Disclaimer:</strong> Komiuta is an independent aggregator. Data is scraped for demonstration purposes.
        Always respect website Terms of Service and robots.txt policies when scraping.</p>
    </div>

</body>
</html>