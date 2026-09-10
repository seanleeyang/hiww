# Pilot smoke test — drives one full order through every stage and checks the
# security controls. Use it to confirm the system is healthy after a change or
# before onboarding a pilot user.
#
#   1. Start the API in another terminal:  npm run dev
#   2. Run this:                            ./scripts/pilot-smoke-test.ps1
#
# It creates throwaway accounts (email suffix = random) and leaves a completed
# + disputed order in the database. Safe to run against a pilot database; run
# `npm run db:setup` afterwards if you want a clean slate.

$ErrorActionPreference = 'Stop'
$api = $env:HIWW_API; if (-not $api) { $api = 'http://localhost:3000' }

function api($method, $path, $body, $headers) {
  $p = @{ Method = $method; Uri = "$api$path"; ContentType = 'application/json' }
  if ($body) { $p.Body = ($body | ConvertTo-Json -Depth 6) }
  if ($headers) { $p.Headers = $headers }
  try { Invoke-RestMethod @p }
  catch { throw "REQUEST FAILED $method $path -> HTTP $($_.Exception.Response.StatusCode.value__): $($_.ErrorDetails.Message)" }
}
function expectFail($method, $path, $body, $headers, $wantCode) {
  $p = @{ Method = $method; Uri = "$api$path" }
  if ($headers) { $p.Headers = $headers }
  if ($body) { $p.ContentType = 'application/json'; $p.Body = ($body | ConvertTo-Json -Depth 6) }
  try { Invoke-RestMethod @p | Out-Null }
  catch {
    $sc = $_.Exception.Response.StatusCode.value__
    if ($sc -eq $wantCode) { Write-Host "  OK  blocked with HTTP $sc" -ForegroundColor Green; return }
    throw "  expected HTTP $wantCode but got HTTP $sc"
  }
  throw "  expected HTTP $wantCode but the request succeeded"
}

$sfx = Get-Random
Write-Host "== Health ==" -ForegroundColor Cyan
(api GET /health).status

Write-Host "`n== Register admin / shopper / traveler ==" -ForegroundColor Cyan
$adminReg    = api POST /api/auth/register @{ email = "admin$sfx@smoke.local";    full_name = 'Smoke Admin';    user_type = 'both';    phone = '+1 555 0100'; password = 'SmokePass123!' }
$shopperReg  = api POST /api/auth/register @{ email = "shopper$sfx@smoke.local";  full_name = 'Smoke Shopper';  user_type = 'shopper'; phone = '+1 555 0101'; password = 'SmokePass123!' }
$travelerReg = api POST /api/auth/register @{ email = "traveler$sfx@smoke.local"; full_name = 'Smoke Traveler'; user_type = 'traveler'; phone = '+1 555 0102'; password = 'SmokePass123!' }

# Registration leaves the account unverified (src/services/otp/); the mock
# sender echoes the codes back as debug_otp so this script can finish
# verification without a real inbox/SMS.
function verifyAccount($reg) {
  $headers = @{ Authorization = "Bearer $($reg.data.token)" }
  if ($reg.data.debug_otp) {
    api POST /api/auth/verify-otp @{ channel = 'email'; code = $reg.data.debug_otp.email } $headers | Out-Null
    api POST /api/auth/verify-otp @{ channel = 'phone'; code = $reg.data.debug_otp.phone } $headers | Out-Null
  }
}
verifyAccount $adminReg
verifyAccount $shopperReg
verifyAccount $travelerReg
Write-Host "  email + phone verified for all three accounts"

Write-Host "   promoting admin (needs shell access)..." -ForegroundColor DarkGray
npm run --silent make-admin "admin$sfx@smoke.local" | Out-Null

$admin    = @{ Authorization = "Bearer $((api POST /api/auth/login @{ email = "admin$sfx@smoke.local";    password = 'SmokePass123!' }).data.token)" }
$shopper  = @{ Authorization = "Bearer $((api POST /api/auth/login @{ email = "shopper$sfx@smoke.local";  password = 'SmokePass123!' }).data.token)" }
$traveler = @{ Authorization = "Bearer $((api POST /api/auth/login @{ email = "traveler$sfx@smoke.local"; password = 'SmokePass123!' }).data.token)" }
$shopperId  = $shopperReg.data.userId
$travelerId = $travelerReg.data.userId

Write-Host "`n== Marketplace flow ==" -ForegroundColor Cyan
api POST "/api/admin/users/$shopperId/kyc-review"  @{ status = 'approved'; note = 'smoke' } $admin  | Out-Null
api POST "/api/admin/users/$travelerId/kyc-review" @{ status = 'approved'; note = 'smoke' } $admin | Out-Null
Write-Host "  KYC approved"
$req   = api POST /api/requests @{ item_description = 'Smoke test item x2'; source_country = 'US'; category = 'general'; estimated_weight_kg = 1; budget = '90.00' } $shopper
$trip  = api POST /api/trips @{ departure_country = 'US'; arrival_country = 'TH'; departure_date = '2026-10-01T08:00:00.000Z'; return_date = '2026-10-10T08:00:00.000Z'; max_weight_kg = 20; max_items = 5 } $traveler
$offer = api POST /api/offers @{ request_id = $req.data.id; trip_id = $trip.data.id; quoted_price = '85.00'; delivery_date = '2026-10-08T10:00:00.000Z' } $traveler
# The offer already carries the trip and price; accepting takes no body.
$order = api POST "/api/offers/$($offer.data.id)/accept" @{ accepted = $true } $shopper
$orderId = $order.data.order_id
Write-Host "  order $orderId created (pending_payment)"

Write-Host "`n== Security checks ==" -ForegroundColor Cyan
Write-Host "  shopper cannot confirm their own payment:"
expectFail POST /api/payments/confirm @{ order_id = $orderId } $shopper 403
Write-Host "  unauthenticated cannot read the admin queue:"
expectFail GET /api/admin/reviews $null $null 401

Write-Host "`n== Admin confirms payment, order ships and completes ==" -ForegroundColor Cyan
api POST /api/payments/confirm @{ order_id = $orderId; payment_id = 'SMOKE-REF' } $admin | Out-Null; Write-Host "  payment confirmed"
api POST /api/payments/confirm @{ order_id = $orderId; payment_id = 'SMOKE-REF' } $admin | Out-Null; Write-Host "  confirm again -> idempotent OK"
api POST "/api/orders/$orderId/purchase-proof" @{ image_url = 'https://placehold.co/600x800?text=Receipt' } $traveler | Out-Null; Write-Host "  traveler uploaded purchase receipt"
api POST "/api/orders/$orderId/deliver" @{ note = 'shipped' } $traveler | Out-Null; Write-Host "  traveler marked shipped"
api POST "/api/orders/$orderId/release" @{ note = 'received'; image_url = 'https://placehold.co/600x800?text=Delivery+Photo' } $shopper | Out-Null; Write-Host "  shopper confirmed receipt"
$final = (api GET "/api/orders/$orderId" $null $admin).data
if ($final.status -ne 'delivered') { throw "expected delivered, got $($final.status)" }
Write-Host "  final status: $($final.status)"

$ledger = api GET "/api/ledger/$travelerId" $null $admin
if ($ledger.data.entries.Count -ne 0) { throw "ledger should be empty in the manual-money pilot" }
Write-Host "  ledger empty (correct for manual-money pilot)"

Write-Host "`n== Dispute flow ==" -ForegroundColor Cyan
$d = api POST /api/disputes @{ order_id = $orderId; reason = 'One box missing from the parcel on arrival' } $shopper
api POST "/api/admin/disputes/$($d.data.id)/resolve" @{ status = 'resolved'; resolution = 'Smoke test: refunded shopper 42.50, noted in spreadsheet.' } $admin | Out-Null
Write-Host "  dispute opened and resolved by admin"

Write-Host "`nALL CHECKS PASSED" -ForegroundColor Green
