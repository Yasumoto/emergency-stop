# Red Button

<div>
    <a href="https://swift.org">
        <img src="http://img.shields.io/badge/swift-4.2-brightgreen.svg" alt="Swift 4.2">
    </a>
</div>

This is a service used to check the status of a `SafeToProceed` value in a `DynamoDB` table. It assumes that if the "lock" is empty, all changes are clear to be made. If there is a value present, then someone has determined an issue is present within production; and no non-critical changes should be made.
